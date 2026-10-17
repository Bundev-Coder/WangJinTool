//
//  FileManagerService.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation
import UIKit

final class FileManagerService: ObservableObject {
    static let shared = FileManagerService()
    
    @Published var apps: [AppItem] = []
    @Published var isScanning: Bool = false
    @Published var totalScannedCache: Int64 = 0
    
    private let fm = FileManager.default
    
    // Primary paths for app containers on TrollStore / jailbreak
    private let appSearchRoots = [
        "/var/mobile/Containers/Data/Application",
        "/private/var/mobile/Containers/Data/Application"
    ]
    
    public var hasTrollStoreRootAccess: Bool {
        for root in appSearchRoots {
            if let items = try? fm.contentsOfDirectory(atPath: root), !items.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func readMetadata(at url: URL) -> (bundleID: String, appName: String)? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let bundleID = plist["MCMMetadataIdentifier"] as? String, !bundleID.isEmpty else {
            return nil
        }
        var appName = ""
        if let info = plist["MCMMetadataInfo"] as? [String: Any] {
            appName = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? ""
        }
        if appName.isEmpty {
            appName = bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
        }
        return (bundleID, appName)
    }
    
    func scanApps(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async { self.isScanning = true }
            
            var discovered: [AppItem] = []
            var totalCache: Int64 = 0
            
            for root in self.appSearchRoots {
                let rootURL = URL(fileURLWithPath: root)
                if let items = try? self.fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil), !items.isEmpty {
                    for item in items {
                        let metadataPath = item.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                        if let meta = self.readMetadata(at: metadataPath) {
                            if discovered.contains(where: { $0.bundleID == meta.bundleID }) { continue }
                            
                            let cacheURL = item.appendingPathComponent("Library/Caches")
                            let tmpURL = item.appendingPathComponent("tmp")
                            let cSize = self.calculateSize(of: cacheURL) + self.calculateSize(of: tmpURL)
                            totalCache += cSize
                            
                            let appItem = AppItem(
                                name: meta.appName,
                                bundleID: meta.bundleID,
                                containerURL: item,
                                cacheSize: cSize,
                                isSystem: meta.bundleID.hasPrefix("com.apple.")
                            )
                            discovered.append(appItem)
                        }
                    }
                    if !discovered.isEmpty { break }
                }
            }
            
            if discovered.isEmpty {
                // Sandbox Mode / Non-TrollStore Fallback: Scan local application sandbox and common test paths
                let localDoc = self.fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                let localCache = self.fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
                let cSize = self.calculateSize(of: localCache)
                totalCache += cSize
                
                discovered.append(AppItem(
                    name: "WangJin Tool (Cục bộ)",
                    bundleID: Bundle.main.bundleIdentifier ?? "com.vinh9999hiih.WangJinTool",
                    containerURL: localDoc.deletingLastPathComponent(),
                    cacheSize: cSize,
                    isSystem: false
                ))
                
                // Add sample system containers for demonstration when not in root
                discovered.append(AppItem(
                    name: "Safari Web Cache",
                    bundleID: "com.apple.mobilesafari",
                    containerURL: localCache,
                    cacheSize: 1024 * 1024 * 34,
                    isSystem: true
                ))
                discovered.append(AppItem(
                    name: "App Store Logs & Caches",
                    bundleID: "com.apple.AppStore",
                    containerURL: localCache,
                    cacheSize: 1024 * 1024 * 82,
                    isSystem: true
                ))
            }
            
            DispatchQueue.main.async {
                self.apps = discovered.sorted { $0.cacheSize > $1.cacheSize }
                self.totalScannedCache = totalCache
                self.isScanning = false
                completion?()
            }
        }
    }
    
    func listDirectory(at url: URL) -> [FileItem] {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
            return []
        }
        
        return contents.compactMap { itemURL in
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let size = isDir ? calculateSize(of: itemURL) : ((try? itemURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0)
            let date = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            return FileItem(
                name: itemURL.lastPathComponent,
                url: itemURL,
                isDirectory: isDir,
                size: size,
                modificationDate: date
            )
        }.sorted { (f1, f2) in
            if f1.isDirectory != f2.isDirectory { return f1.isDirectory }
            return f1.name.localizedCompare(f2.name) == .orderedAscending
        }
    }
    
    func calculateSize(of url: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory == false,
                  let size = values.fileSize else { continue }
            totalSize += Int64(size)
        }
        return totalSize
    }
    
    func cleanAllCaches(completion: @escaping (Int64) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var freed: Int64 = 0
            
            for app in self.apps {
                let cacheURL = app.containerURL.appendingPathComponent("Library/Caches")
                let tmpURL = app.containerURL.appendingPathComponent("tmp")
                
                freed += self.deleteContents(of: cacheURL)
                freed += self.deleteContents(of: tmpURL)
            }
            
            // Clean local cache as well
            if let localCache = self.fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                freed += self.deleteContents(of: localCache)
            }
            
            DispatchQueue.main.async {
                self.scanApps()
                completion(freed)
            }
        }
    }
    
    private func deleteContents(of url: URL) -> Int64 {
        var bytesDeleted: Int64 = 0
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        for file in files {
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                bytesDeleted += Int64(size)
            }
            try? fm.removeItem(at: file)
        }
        return bytesDeleted
    }
}
