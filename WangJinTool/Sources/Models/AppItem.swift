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
    public var documentsSize: Int64
    public var totalSize: Int64
    public let isSystem: Bool
    
    public init(
        name: String,
        bundleID: String,
        containerURL: URL,
        cacheSize: Int64 = 0,
        documentsSize: Int64 = 0,
        totalSize: Int64 = 0,
        isSystem: Bool = false
    ) {
        self.id = bundleID
        self.name = name
        self.bundleID = bundleID
        self.containerURL = containerURL
        self.cacheSize = cacheSize
        self.documentsSize = documentsSize
        self.totalSize = totalSize > 0 ? totalSize : (cacheSize + documentsSize)
        self.isSystem = isSystem
    }

    public var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var formattedDocumentsSize: String {
        ByteCountFormatter.string(fromByteCount: documentsSize, countStyle: .file)
    }
}

public struct FileItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    public let size: Int64
    public let itemCount: Int
    public let modificationDate: Date?
    
    public init(name: String, url: URL, isDirectory: Bool, size: Int64, itemCount: Int = 0, modificationDate: Date?) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.size = size
        self.itemCount = itemCount
        self.modificationDate = modificationDate
    }

    public var formattedSize: String {
        if isDirectory {
            return itemCount > 0 ? "\(itemCount) mục" : "Thư mục"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
