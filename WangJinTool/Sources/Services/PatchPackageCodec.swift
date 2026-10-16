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
            return "Gói yêu cầu mật khẩu bảo vệ hoặc mật khẩu bạn nhập chưa chính xác."
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

    // MARK: - Inspect Package Metadata
    public static func inspectPackage(_ data: Data) throws -> (packageID: String, isPasswordProtected: Bool) {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            throw PatchPackageError.unsupportedFormat
        }

        let encodedEnvelope = data.dropFirst(magic.count)
        guard let plist = try? PropertyListSerialization.propertyList(from: Data(encodedEnvelope), options: [], format: nil),
              let dict = plist as? [String: Any] else {
            throw PatchPackageError.unsupportedFormat
        }

        let pkgID = parsePackageID(from: dict["packageID"])
        let isProtected = (dict["isPasswordProtected"] as? Bool) ?? (dict["wrappedContentKey"] != nil)
        return (pkgID, isProtected)
    }

    // MARK: - Decode Package
    public static func decode(_ data: Data, password: String? = nil) throws -> PatchProject {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            throw PatchPackageError.unsupportedFormat
        }

        let encodedEnvelope = data.dropFirst(magic.count)
        guard let plist = try? PropertyListSerialization.propertyList(from: Data(encodedEnvelope), options: [], format: nil),
              let dict = plist as? [String: Any] else {
            throw PatchPackageError.unsupportedFormat
        }

        let schemaVersion = parseSchemaVersion(from: dict["schemaVersion"])
        let keyAADVersion = dict["keyAADVersion"] as? Int ?? schemaVersion
        let packageID = parsePackageID(from: dict["packageID"])
        let isProtected = (dict["isPasswordProtected"] as? Bool) ?? (dict["wrappedContentKey"] != nil)

        let contentKey: Data
        if isProtected {
            guard let password = password, !password.isEmpty else {
                throw PatchPackageError.invalidPassword
            }
            guard let salt = dict["kdfSalt"] as? Data,
                  let wrappedKey = dict["wrappedContentKey"] as? Data else {
                throw PatchPackageError.invalidPassword
            }
            let iterations = (dict["kdfIterations"] as? Int) ?? 100_000
            let wrappingKey = try deriveKey(password: password, salt: salt, iterations: iterations)

            // Try with primary version, then fallback versions
            var decryptedKey: Data?
            let versionsToTry = [keyAADVersion, schemaVersion, 3, 2, 1, 0]
            for ver in versionsToTry {
                let aad = keyAAD(for: packageID, version: ver)
                if let key = try? open(wrappedKey, key: wrappingKey, aad: aad) {
                    decryptedKey = key
                    break
                }
            }

            guard let key = decryptedKey else {
                throw PatchPackageError.invalidPassword
            }
            contentKey = key
        } else {
            guard let storedKey = dict["publicContentKey"] as? Data, storedKey.count == 32 else {
                throw PatchPackageError.missingContentKey
            }
            contentKey = storedKey
        }

        // Optional key fingerprint check
        if let expectedFingerprint = dict["keyFingerprint"] as? Data, expectedFingerprint.count == 32 {
            if fingerprint(contentKey) != expectedFingerprint {
                throw PatchPackageError.invalidPassword
            }
        }

        guard let encryptedPayload = dict["encryptedPayload"] as? Data, encryptedPayload.count >= 28 else {
            throw PatchPackageError.corruptedPayload
        }

        // Decrypt payload with primary version, then fallback versions
        var decryptedPayload: Data?
        let payloadVersions = [schemaVersion, keyAADVersion, 3, 2, 1, 0]
        for ver in payloadVersions {
            let pAAD = payloadAAD(for: packageID, version: ver)
            if let pData = try? open(encryptedPayload, key: contentKey, aad: pAAD) {
                decryptedPayload = pData
                break
            }
        }

        guard let payloadData = decryptedPayload else {
            throw PatchPackageError.corruptedPayload
        }

        // Parse Payload Plist
        guard let payloadPlist = try? PropertyListSerialization.propertyList(from: payloadData, options: [], format: nil) else {
            throw PatchPackageError.corruptedPayload
        }

        let rootDict = (payloadPlist as? [String: Any]) ?? [:]
        let projectDict = (rootDict["project"] as? [String: Any]) ?? rootDict

        let projName = projectDict["name"] as? String ?? "Bản vá .3105"
        let projAuthor = projectDict["author"] as? String ?? "3105 Community"
        let projPrivate = isProtected
        let bundleIDs = (projectDict["bundleIdentifiers"] as? [String]) ?? []

        var rules: [PatchRule] = []
        if let rawRules = projectDict["rules"] as? [[String: Any]] {
            for raw in rawRules {
                guard let relPath = raw["relativePath"] as? String,
                      let repData = raw["replacementData"] as? Data else {
                    continue
                }
                let bID = raw["bundleID"] as? String ?? bundleIDs.first ?? ""
                let fName = raw["replacementFilename"] as? String ?? (relPath as NSString).lastPathComponent
                let rID = (raw["id"] as? String).flatMap(UUID.init) ?? UUID()

                rules.append(PatchRule(
                    id: rID,
                    bundleID: bID,
                    relativePath: relPath,
                    replacementFilename: fName,
                    replacementData: repData
                ))
            }
        }

        let pID = UUID(uuidString: packageID) ?? UUID()
        return PatchProject(
            id: pID,
            name: projName,
            author: projAuthor,
            isPrivate: projPrivate,
            bundleIdentifiers: bundleIDs,
            rules: rules
        )
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
            let aad = keyAAD(for: project.id.uuidString, version: latestSchemaVersion)
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

        let rulesArray: [[String: Any]] = project.rules.map { rule in
            [
                "id": rule.id.uuidString,
                "bundleID": rule.bundleID,
                "relativePath": rule.relativePath,
                "replacementFilename": rule.replacementFilename,
                "replacementData": rule.replacementData
            ]
        }

        let projectDict: [String: Any] = [
            "id": project.id.uuidString,
            "name": project.name,
            "author": project.author,
            "isPrivate": project.isPrivate,
            "createdAt": project.createdAt,
            "updatedAt": project.updatedAt,
            "bundleIdentifiers": project.bundleIdentifiers,
            "rules": rulesArray
        ]

        let payloadDict: [String: Any] = [
            "project": projectDict,
            "replacementDigests": digests
        ]

        let payloadData = try PropertyListSerialization.data(fromPropertyList: payloadDict, format: .binary, options: 0)
        let pAAD = payloadAAD(for: project.id.uuidString, version: latestSchemaVersion)
        let encryptedPayload = try seal(payloadData, key: contentKey, aad: pAAD)

        var envDict: [String: Any] = [
            "schemaVersion": latestSchemaVersion,
            "packageID": project.id.uuidString,
            "isPasswordProtected": isProtected,
            "keyFingerprint": fingerprint(contentKey),
            "encryptedPayload": encryptedPayload
        ]

        if isProtected {
            envDict["keyAADVersion"] = latestSchemaVersion
            envDict["kdfSalt"] = salt
            envDict["kdfIterations"] = iterations
            envDict["wrappedContentKey"] = wrappedKey
        } else {
            envDict["publicContentKey"] = publicKey
        }

        let envelopeData = try PropertyListSerialization.data(fromPropertyList: envDict, format: .binary, options: 0)
        var result = magic
        result.append(envelopeData)
        return result
    }

    // MARK: - Cryptographic Helpers
    private static func parseSchemaVersion(from value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let s = value as? String, let v = Int(s) { return v }
        if let n = value as? NSNumber { return n.intValue }
        return 3
    }

    private static func parsePackageID(from value: Any?) -> String {
        if let s = value as? String { return s }
        if let u = value as? UUID { return u.uuidString }
        return UUID().uuidString
    }

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

    private static func keyAAD(for packageID: String, version: Int) -> Data {
        Data("3105PATCH/v\(version)/key/\(packageID)".utf8)
    }

    private static func payloadAAD(for packageID: String, version: Int) -> Data {
        Data("3105PATCH/v\(version)/payload/\(packageID)".utf8)
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
