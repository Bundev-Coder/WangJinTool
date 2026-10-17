//
//  PatchManagerService.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation
import UIKit

public final class PatchManagerService: ObservableObject {
    public static let shared = PatchManagerService()

    @Published public var installedPatches: [InstalledPatchRecord] = []
    @Published public var isProcessing: Bool = false
    @Published public var pendingPasswordProtectedURL: URL? = nil

    public func isPackageProtected(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let info = try? PatchPackageCodec.inspectPackage(data) else {
            return false
        }
        return info.isPasswordProtected
    }

    private let fm = FileManager.default
    private let appContainersRoot = "/var/mobile/Containers/Data/Application"
    private let groupContainersRoot = "/var/mobile/Containers/Shared/AppGroup"

    private var patchesDirectory: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("3105Patches", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var backupsDirectory: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("3105Backups", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var registryFileURL: URL {
        patchesDirectory.appendingPathComponent("patches_registry.json")
    }

    public init() {
        loadRegistry()
        if installedPatches.isEmpty {
            createSamplePatchIfNeeded()
        }
    }

    // MARK: - Registry Persistence
    private func loadRegistry() {
        guard let data = try? Data(contentsOf: registryFileURL),
              let list = try? JSONDecoder().decode([InstalledPatchRecord].self, from: data) else {
            return
        }
        self.installedPatches = list
    }

    private func saveRegistry() {
        if let data = try? JSONEncoder().encode(installedPatches) {
            try? data.write(to: registryFileURL)
        }
    }

    // MARK: - Import .3105 Package
    public func importPackage(from url: URL, password: String? = nil) throws -> InstalledPatchRecord {
        guard url.startAccessingSecurityScopedResource() || true else {
            throw PatchPackageError.unsupportedFormat
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let project = try PatchPackageCodec.decode(data, password: password)

        // Save raw package file
        let dest = patchesDirectory.appendingPathComponent("\(project.id.uuidString).3105")
        try data.write(to: dest)

        let record = InstalledPatchRecord(project: project)
        if let idx = installedPatches.firstIndex(where: { $0.id == record.id }) {
            installedPatches[idx] = record
        } else {
            installedPatches.insert(record, at: 0)
        }
        saveRegistry()
        return record
    }

    // MARK: - Apply Patch
    public func applyPatch(record: InstalledPatchRecord) throws {
        isProcessing = true
        defer { isProcessing = false }

        let backupFolder = backupsDirectory.appendingPathComponent(record.id.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: backupFolder.path) {
            try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        }

        // Apply rules
        for rule in record.project.rules {
            guard let containerURL = resolveContainer(for: rule.bundleID) else {
                throw PatchPackageError.targetAppUnavailable(rule.bundleID)
            }

            let targetFileURL = containerURL.appendingPathComponent(rule.relativePath)
            let parentDir = targetFileURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: parentDir.path) {
                try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            // Backup existing file if present
            let backupTarget = backupFolder.appendingPathComponent("\(rule.id.uuidString).bak")
            if fm.fileExists(atPath: targetFileURL.path) {
                if !fm.fileExists(atPath: backupTarget.path) {
                    try? fm.copyItem(at: targetFileURL, to: backupTarget)
                }
            } else {
                // Write a zero-byte marker indicating file was newly created
                try? Data().write(to: backupFolder.appendingPathComponent("\(rule.id.uuidString).created"))
            }

            // Write replacement data
            try rule.replacementData.write(to: targetFileURL, options: .atomic)
        }

        if let idx = installedPatches.firstIndex(where: { $0.id == record.id }) {
            installedPatches[idx].isApplied = true
            installedPatches[idx].lastAppliedAt = Date()
            installedPatches[idx].backupFolderURLString = backupFolder.path
            saveRegistry()
        }
    }

    // MARK: - Restore / Rollback Patch
    public func restorePatch(record: InstalledPatchRecord) throws {
        isProcessing = true
        defer { isProcessing = false }

        let backupFolder = backupsDirectory.appendingPathComponent(record.id.uuidString, isDirectory: true)

        for rule in record.project.rules {
            guard let containerURL = resolveContainer(for: rule.bundleID) else { continue }
            let targetFileURL = containerURL.appendingPathComponent(rule.relativePath)
            let backupFile = backupFolder.appendingPathComponent("\(rule.id.uuidString).bak")
            let createdMarker = backupFolder.appendingPathComponent("\(rule.id.uuidString).created")

            if fm.fileExists(atPath: backupFile.path) {
                try? fm.removeItem(at: targetFileURL)
                try? fm.copyItem(at: backupFile, to: targetFileURL)
            } else if fm.fileExists(atPath: createdMarker.path) {
                // If it was created by patch, remove it
                try? fm.removeItem(at: targetFileURL)
            }
        }

        // Cleanup backups
        try? fm.removeItem(at: backupFolder)

        if let idx = installedPatches.firstIndex(where: { $0.id == record.id }) {
            installedPatches[idx].isApplied = false
            installedPatches[idx].backupFolderURLString = nil
            saveRegistry()
        }
    }

    // MARK: - Delete Patch
    public func deletePatch(record: InstalledPatchRecord) {
        if record.isApplied {
            try? restorePatch(record: record)
        }
        let packageFile = patchesDirectory.appendingPathComponent("\(record.id.uuidString).3105")
        try? fm.removeItem(at: packageFile)
        installedPatches.removeAll { $0.id == record.id }
        saveRegistry()
    }

    // MARK: - Export / Share Package
    public func packageFileURL(for record: InstalledPatchRecord) -> URL? {
        let dest = patchesDirectory.appendingPathComponent("\(record.id.uuidString).3105")
        if fm.fileExists(atPath: dest.path) {
            return dest
        }
        // If not cached, re-encode
        if let encoded = try? PatchPackageCodec.encode(project: record.project) {
            try? encoded.write(to: dest)
            return dest
        }
        return nil
    }

    // MARK: - Create Custom .3105 Patch
    public func createNewPatch(
        name: String,
        author: String,
        password: String? = nil,
        rules: [PatchRule]
    ) throws -> InstalledPatchRecord {
        var bundleIDs = Set<String>()
        for r in rules { bundleIDs.insert(r.bundleID) }

        let project = PatchProject(
            name: name,
            author: author.isEmpty ? "WangJin User" : author,
            isPrivate: !(password ?? "").isEmpty,
            bundleIdentifiers: Array(bundleIDs),
            rules: rules
        )

        let encoded = try PatchPackageCodec.encode(project: project, password: password)
        let fileURL = patchesDirectory.appendingPathComponent("\(project.id.uuidString).3105")
        try encoded.write(to: fileURL)

        let record = InstalledPatchRecord(project: project)
        installedPatches.insert(record, at: 0)
        saveRegistry()
        return record
    }

    // MARK: - Update Patch Configuration
    public func updatePatch(record: InstalledPatchRecord, targetBundleID: String? = nil, updatedRules: [PatchRule]? = nil) {
        guard let idx = installedPatches.firstIndex(where: { $0.id == record.id }) else { return }
        
        var project = installedPatches[idx].project
        if let target = targetBundleID, !target.isEmpty {
            project.bundleIdentifiers = [target]
            for i in 0..<project.rules.count {
                project.rules[i].bundleID = target
            }
        }
        if let rules = updatedRules {
            project.rules = rules
        }
        project.updatedAt = Date()
        installedPatches[idx].project = project
        saveRegistry()
    }

    // MARK: - Resolve Target Container Path
    private let appSearchRoots = [
        "/var/mobile/Containers/Data/Application",
        "/private/var/mobile/Containers/Data/Application"
    ]
    private let groupSearchRoots = [
        "/var/mobile/Containers/Shared/AppGroup",
        "/private/var/mobile/Containers/Shared/AppGroup"
    ]

    public func resolveContainer(for bundleID: String) -> URL? {
        let isGroup = bundleID.hasPrefix("group.")
        let roots = isGroup ? groupSearchRoots : appSearchRoots
        
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            if let items = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil), !items.isEmpty {
                for item in items {
                    let metadataPath = item.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                    if let data = try? Data(contentsOf: metadataPath),
                       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                       let mcmID = plist["MCMMetadataIdentifier"] as? String,
                       mcmID == bundleID {
                        return item
                    }
                }
            }
        }
        return nil
    }

    // Sample initial patch for immediate demonstration
    private func createSamplePatchIfNeeded() {
        let sampleRule = PatchRule(
            bundleID: "com.apple.mobilesafari",
            relativePath: "Library/Preferences/com.apple.mobilesafari.plist",
            replacementFilename: "com.apple.mobilesafari.plist",
            replacementData: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>DebugMenuEnabled</key>\n\t<true/>\n\t<key>WebKitDeveloperExtras</key>\n\t<true/>\n</dict>\n</plist>".data(using: .utf8)!
        )

        let sampleProject = PatchProject(
            name: "Safari WebKit Developer Mode",
            author: "WangJin & 3105 Community",
            bundleIdentifiers: ["com.apple.mobilesafari"],
            rules: [sampleRule]
        )

        let sampleRecord = InstalledPatchRecord(project: sampleProject)
        installedPatches.append(sampleRecord)
        saveRegistry()
    }
}
