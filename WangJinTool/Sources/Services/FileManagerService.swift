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
    @Published var totalScannedData: Int64 = 0
    
    private let fm = FileManager.default
    
    // Primary paths for app containers on TrollStore / jailbreak
    private let appSearchRoots = [
        "/var/mobile/Containers/Data/Application",
        "/private/var/mobile/Containers/Data/Application"
    ]

    private let groupSearchRoots = [
        "/var/mobile/Containers/Shared/AppGroup",
        "/private/var/mobile/Containers/Shared/AppGroup"
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

    private func findContainerInDisk(matching bundleID: String) -> URL? {
        let isGroup = bundleID.hasPrefix("group.")
        let roots = isGroup ? groupSearchRoots : appSearchRoots
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            if let items = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) {
                for item in items {
                    let metaPath = item.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                    if let meta = readMetadata(at: metaPath), meta.bundleID == bundleID {
                        return item
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Scan Apps via LSApplicationWorkspace (iOS Private API)
    private func scanViaWorkspace() -> [AppItem] {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
              let appsList = workspace.perform(NSSelectorFromString("allApplications"))?.takeUnretainedValue() as? [NSObject] else {
            return []
        }

        var results: [AppItem] = []
        for proxy in appsList {
            guard let bundleID = proxy.perform(NSSelectorFromString("applicationIdentifier"))?.takeUnretainedValue() as? String,
                  !bundleID.isEmpty else {
                continue
            }

            let name = proxy.perform(NSSelectorFromString("localizedName"))?.takeUnretainedValue() as? String ?? bundleID
            let appType = (proxy.perform(NSSelectorFromString("applicationType"))?.takeUnretainedValue() as? String ?? "User").lowercased()
            let isSystem = appType.contains("system") || bundleID.hasPrefix("com.apple.")

            var containerURL: URL? = nil
            if let val = proxy.perform(NSSelectorFromString("containerURL"))?.takeUnretainedValue() {
                if let u = val as? URL {
                    containerURL = u
                } else if let s = val as? NSString {
                    containerURL = URL(fileURLWithPath: s as String)
                }
            }

            if containerURL == nil {
                containerURL = findContainerInDisk(matching: bundleID)
            }

            // Fallback for system apps or sandbox testing
            if containerURL == nil, let bURL = proxy.perform(NSSelectorFromString("bundleURL"))?.takeUnretainedValue() as? URL {
                containerURL = bURL
            }

            if let container = containerURL {
                let cacheSize = calculateSize(of: container.appendingPathComponent("Library/Caches")) +
                                calculateSize(of: container.appendingPathComponent("tmp"))
                let docSize = calculateSize(of: container.appendingPathComponent("Documents"))
                let totalSize = calculateSize(of: container)

                results.append(AppItem(
                    name: name,
                    bundleID: bundleID,
                    containerURL: container,
                    cacheSize: cacheSize,
                    documentsSize: docSize,
                    totalSize: max(totalSize, docSize + cacheSize),
                    isSystem: isSystem
                ))
            }
        }
        return results
    }
    
    func scanApps(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async { self.isScanning = true }
            
            var discovered: [AppItem] = []
            var totalCache: Int64 = 0
            var totalData: Int64 = 0

            // Method 1: Scan via LSApplicationWorkspace (Discovers ALL user & system apps on device)
            let workspaceApps = self.scanViaWorkspace()
            for app in workspaceApps {
                if !discovered.contains(where: { $0.bundleID == app.bundleID }) {
                    discovered.append(app)
                    totalCache += app.cacheSize
                    totalData += app.totalSize
                }
            }
            
            // Method 2: Scan raw container directories on disk
            for root in self.appSearchRoots {
                let rootURL = URL(fileURLWithPath: root)
                if let items = try? self.fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil), !items.isEmpty {
                    for item in items {
                        let metadataPath = item.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                        if let meta = self.readMetadata(at: metadataPath) {
                            if discovered.contains(where: { $0.bundleID == meta.bundleID }) { continue }
                            
                            let cacheURL = item.appendingPathComponent("Library/Caches")
                            let tmpURL = item.appendingPathComponent("tmp")
                            let docURL = item.appendingPathComponent("Documents")

                            let cSize = self.calculateSize(of: cacheURL) + self.calculateSize(of: tmpURL)
                            let dSize = self.calculateSize(of: docURL)
                            let tSize = max(self.calculateSize(of: item), dSize + cSize)

                            totalCache += cSize
                            totalData += tSize
                            
                            let appItem = AppItem(
                                name: meta.appName,
                                bundleID: meta.bundleID,
                                containerURL: item,
                                cacheSize: cSize,
                                documentsSize: dSize,
                                totalSize: tSize,
                                isSystem: meta.bundleID.hasPrefix("com.apple.")
                            )
                            discovered.append(appItem)
                        }
                    }
                }
            }
            
            // Method 3: Fallback if running strictly isolated
            if discovered.isEmpty {
                let localDoc = self.fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                let localCache = self.fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
                let cSize = self.calculateSize(of: localCache)
                let dSize = self.calculateSize(of: localDoc)
                let tSize = cSize + dSize
                totalCache += cSize
                totalData += tSize
                
                discovered.append(AppItem(
                    name: "WangJin Tool (Cục bộ)",
                    bundleID: Bundle.main.bundleIdentifier ?? "com.vinh9999hiih.WangJinTool",
                    containerURL: localDoc.deletingLastPathComponent(),
                    cacheSize: cSize,
                    documentsSize: dSize,
                    totalSize: tSize,
                    isSystem: false
                ))
            }
            
            DispatchQueue.main.async {
                self.apps = discovered.sorted { $0.totalSize > $1.totalSize }
                self.totalScannedCache = totalCache
                self.totalScannedData = totalData
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
            var size: Int64 = 0
            var count: Int = 0
            if isDir {
                count = (try? fm.contentsOfDirectory(atPath: itemURL.path))?.count ?? 0
            } else {
                size = (try? itemURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
            }
            let date = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            return FileItem(
                name: itemURL.lastPathComponent,
                url: itemURL,
                isDirectory: isDir,
                size: size,
                itemCount: count,
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
