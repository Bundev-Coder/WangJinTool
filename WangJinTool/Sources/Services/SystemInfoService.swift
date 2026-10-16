//
//  SystemInfoService.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation
import UIKit

final class SystemInfoService: ObservableObject {
    static let shared = SystemInfoService()
    
    @Published var totalDiskSpace: Int64 = 0
    @Published var freeDiskSpace: Int64 = 0
    @Published var usedDiskSpace: Int64 = 0
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    init() {
        refresh()
    }
    
    func refresh() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        thermalState = ProcessInfo.processInfo.thermalState
        
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            if let total = attributes[.systemSize] as? Int64,
               let free = attributes[.systemFreeSize] as? Int64 {
                self.totalDiskSpace = total
                self.freeDiskSpace = free
                self.usedDiskSpace = total - free
            }
        }
    }
    
    var formattedTotalDisk: String {
        ByteCountFormatter.string(fromByteCount: totalDiskSpace, countStyle: .file)
    }
    
    var formattedFreeDisk: String {
        ByteCountFormatter.string(fromByteCount: freeDiskSpace, countStyle: .file)
    }
    
    var formattedUsedDisk: String {
        ByteCountFormatter.string(fromByteCount: usedDiskSpace, countStyle: .file)
    }
    
    var diskUsagePercentage: Double {
        guard totalDiskSpace > 0 else { return 0.0 }
        return Double(usedDiskSpace) / Double(totalDiskSpace)
    }
    
    var deviceModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
    
    var osVersion: String {
        "iOS \(UIDevice.current.systemVersion)"
    }
}
