//
//  PatchPackageCodec.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation
import CommonCrypto
import CryptoKit

public enum PatchPackageError: LocalizedError {
    case unsupportedFormat
    case unsupportedVersion
    case invalidPassword
    case corruptedPayload
    case missingContentKey
    case encryptionFailed
    case targetAppUnavailable(String)
    case restoreFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Định dạng gói không hợp lệ. Tệp không có chữ ký 3105 hợp lệ."
        case .unsupportedVersion:
            return "Phiên bản schema gói .3105 này chưa được hỗ trợ."
        case .invalidPassword:
            return "Mật khẩu gói .3105 không chính xác hoặc gói đã bị hỏng."
        case .corruptedPayload:
            return "Nội dung bản vá .3105 bị hỏng hoặc chữ ký kiểm tra không khớp."
        case .missingContentKey:
            return "Không tìm thấy khóa giải mã trong gói công khai."
        case .encryptionFailed:
            return "Lỗi trong quá trình mã hóa/giải mã AES-GCM."
        case .targetAppUnavailable(let bundleID):
            return "Không tìm thấy container ứng dụng mục tiêu: \(bundleID)"
        case .restoreFailed(let msg):
            return "Khôi phục dữ liệu ban đầu thất bại: \(msg)"
        }
    }
}

public enum PatchPackageCodec {
    private static let magic = Data("3105PATCH\0".utf8)
    public static let latestSchemaVersion = 3
    private static let minimumSchemaVersion = 1

    private struct Envelope: Codable {
        let schemaVersion: Int
        let keyAADVersion: Int?
        let packageID: UUID
        let isPasswordProtected: Bool
        let kdfSalt: Data?
        let kdfIterations: Int?
        let wrappedContentKey: Data?
        let publicContentKey: Data?
        let keyFingerprint: Data
        let encryptedPayload: Data
    }

    private struct Payload: Codable {
        let project: PatchProject
        let replacementDigests: [String: Data]
    }

    // MARK: - Inspect Package Metadata
    public static func inspectPackage(_ data: Data) throws -> (packageID: UUID, isPasswordProtected: Bool) {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            throw PatchPackageError.unsupportedFormat
        }

        let encodedEnvelope = data.dropFirst(magic.count)
        guard let envelope = try? PropertyListDecoder().decode(Envelope.self, from: Data(encodedEnvelope)) else {
            throw PatchPackageError.unsupportedFormat
        }

        guard (minimumSchemaVersion...latestSchemaVersion).contains(envelope.schemaVersion) else {
            throw PatchPackageError.unsupportedVersion
        }

        return (envelope.packageID, envelope.isPasswordProtected)
    }

    // MARK: - Decode Package
    public static func decode(_ data: Data, password: String? = nil) throws -> PatchProject {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            throw PatchPackageError.unsupportedFormat
        }

        let encodedEnvelope = data.dropFirst(magic.count)
        guard let envelope = try? PropertyListDecoder().decode(Envelope.self, from: Data(encodedEnvelope)) else {
            throw PatchPackageError.unsupportedFormat
        }

        guard (minimumSchemaVersion...latestSchemaVersion).contains(envelope.schemaVersion) else {
            throw PatchPackageError.unsupportedVersion
        }

        let contentKey: Data
        if envelope.isPasswordProtected {
            guard let password = password, !password.isEmpty,
                  let salt = envelope.kdfSalt,
                  let iterations = envelope.kdfIterations,
                  let wrappedKey = envelope.wrappedContentKey else {
                throw PatchPackageError.invalidPassword
            }

            let wrappingKey = try deriveKey(password: password, salt: salt, iterations: iterations)
            let aad = keyAAD(for: envelope.packageID, version: envelope.keyAADVersion ?? envelope.schemaVersion)
            do {
                contentKey = try open(wrappedKey, key: wrappingKey, aad: aad)
            } catch {
                throw PatchPackageError.invalidPassword
            }
        } else {
            guard let storedKey = envelope.publicContentKey else {
                throw PatchPackageError.missingContentKey
            }
            contentKey = storedKey
        }

        // Verify key fingerprint
        guard fingerprint(contentKey) == envelope.keyFingerprint else {
            throw PatchPackageError.invalidPassword
        }

        // Decrypt payload
        let payloadAAD = payloadAAD(for: envelope.packageID, version: envelope.schemaVersion)
        let payloadData: Data
        do {
            payloadData = try open(envelope.encryptedPayload, key: contentKey, aad: payloadAAD)
        } catch {
            throw PatchPackageError.corruptedPayload
        }

        guard let payload = try? PropertyListDecoder().decode(Payload.self, from: payloadData) else {
            throw PatchPackageError.corruptedPayload
        }

        // Check project ID
        guard payload.project.id == envelope.packageID else {
            throw PatchPackageError.corruptedPayload
        }

        return payload.project
    }

    // MARK: - Encode Package
    public static func encode(project: PatchProject, password: String? = nil) throws -> Data {
        let contentKey = try randomData(count: 32)
        let isProtected = !(password ?? "").isEmpty
        let salt: Data?
        let iterations: Int?
        let wrappedKey: Data?
        let publicKey: Data?

        if isProtected, let password = password {
            let s = try randomData(count: 16)
            let iter = 100_000
            salt = s
            iterations = iter
            let wrappingKey = try deriveKey(password: password, salt: s, iterations: iter)
            let aad = keyAAD(for: project.id, version: latestSchemaVersion)
            wrappedKey = try seal(contentKey, key: wrappingKey, aad: aad)
            publicKey = nil
        } else {
            salt = nil
            iterations = nil
            wrappedKey = nil
            publicKey = contentKey
        }

        // Compute replacement digests
        var digests: [String: Data] = [:]
        for rule in project.rules {
            digests[rule.id.uuidString] = Data(SHA256.hash(data: rule.replacementData))
        }

        let payload = Payload(project: project, replacementDigests: digests)
        let payloadData = try PropertyListEncoder().encode(payload)
        let pAAD = payloadAAD(for: project.id, version: latestSchemaVersion)
        let encryptedPayload = try seal(payloadData, key: contentKey, aad: pAAD)

        let envelope = Envelope(
            schemaVersion: latestSchemaVersion,
            keyAADVersion: isProtected ? latestSchemaVersion : nil,
            packageID: project.id,
            isPasswordProtected: isProtected,
            kdfSalt: salt,
            kdfIterations: iterations,
            wrappedContentKey: wrappedKey,
            publicContentKey: publicKey,
            keyFingerprint: fingerprint(contentKey),
            encryptedPayload: encryptedPayload
        )

        let envelopeData = try PropertyListEncoder().encode(envelope)
        var result = magic
        result.append(envelopeData)
        return result
    }

    // MARK: - Cryptographic Helpers
    private static func deriveKey(password: String, salt: Data, iterations: Int) throws -> Data {
        let passwordData = Data(password.utf8)
        let derivedKeyLength = 32
        var output = Data(count: derivedKeyLength)
        let status = output.withUnsafeMutableBytes { outputBuffer in
            passwordData.withUnsafeBytes { passwordBuffer in
                salt.withUnsafeBytes { saltBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        outputBuffer.bindMemory(to: UInt8.self).baseAddress,
                        derivedKeyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw PatchPackageError.invalidPassword
        }
        return output
    }

    private static func open(_ ciphertext: Data, key: Data, aad: Data) throws -> Data {
        guard key.count == 32 else { throw PatchPackageError.encryptionFailed }
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
    }

    private static func seal(_ plaintext: Data, key: Data, aad: Data) throws -> Data {
        guard key.count == 32 else { throw PatchPackageError.encryptionFailed }
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: aad)
        guard let combined = sealed.combined else { throw PatchPackageError.encryptionFailed }
        return combined
    }

    private static func fingerprint(_ key: Data) -> Data {
        Data(SHA256.hash(data: key))
    }

    private static func keyAAD(for packageID: UUID, version: Int) -> Data {
        Data("3105PATCH/v\(version)/key/\(packageID.uuidString)".utf8)
    }

    private static func payloadAAD(for packageID: UUID, version: Int) -> Data {
        Data("3105PATCH/v\(version)/payload/\(packageID.uuidString)".utf8)
    }

    private static func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw PatchPackageError.encryptionFailed
        }
        return data
    }
}
