//
//  PatchModels.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation

public struct PatchRule: Codable, Identifiable, Hashable {
    public var id: UUID
    public var bundleID: String
    public var relativePath: String
    public var replacementFilename: String
    public var replacementData: Data

    public init(
        id: UUID = UUID(),
        bundleID: String,
        relativePath: String,
        replacementFilename: String,
        replacementData: Data
    ) {
        self.id = id
        self.bundleID = bundleID
        self.relativePath = relativePath
        self.replacementFilename = replacementFilename
        self.replacementData = replacementData
    }

    public var hasReplacement: Bool {
        !replacementFilename.isEmpty
    }
}

public struct PatchDirectory: Codable, Identifiable, Hashable {
    public var id: UUID
    public var bundleID: String
    public var relativePath: String

    public init(
        id: UUID = UUID(),
        bundleID: String,
        relativePath: String
    ) {
        self.id = id
        self.bundleID = bundleID
        self.relativePath = relativePath
    }
}

public struct PatchProject: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var author: String
    public var isPrivate: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var bundleIdentifiers: [String]
    public var directories: [PatchDirectory]
    public var rules: [PatchRule]

    public init(
        id: UUID = UUID(),
        name: String,
        author: String = "WangJin User",
        isPrivate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        bundleIdentifiers: [String] = [],
        directories: [PatchDirectory] = [],
        rules: [PatchRule] = []
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bundleIdentifiers = bundleIdentifiers
        self.directories = directories
        self.rules = rules
    }

    public var allBundleIdentifiers: [String] {
        var set = Set<String>(bundleIdentifiers)
        for r in rules { set.insert(r.bundleID) }
        for d in directories { set.insert(d.bundleID) }
        return Array(set).sorted()
    }
}

public struct InstalledPatchRecord: Codable, Identifiable, Hashable {
    public var id: UUID
    public var project: PatchProject
    public var importedAt: Date
    public var isApplied: Bool
    public var lastAppliedAt: Date?
    public var backupFolderURLString: String?

    public init(
        project: PatchProject,
        isApplied: Bool = false,
        backupFolderURLString: String? = nil
    ) {
        self.id = project.id
        self.project = project
        self.importedAt = Date()
        self.isApplied = isApplied
        self.lastAppliedAt = isApplied ? Date() : nil
        self.backupFolderURLString = backupFolderURLString
    }
}
