//
//  AppItem.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation

public struct AppItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let bundleID: String
    public let containerURL: URL
    public var cacheSize: Int64
    public let isSystem: Bool
    
    public init(name: String, bundleID: String, containerURL: URL, cacheSize: Int64 = 0, isSystem: Bool = false) {
        self.id = bundleID
        self.name = name
        self.bundleID = bundleID
        self.containerURL = containerURL
        self.cacheSize = cacheSize
        self.isSystem = isSystem
    }
}

public struct FileItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let size: Int64
    public let modificationDate: Date?
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
