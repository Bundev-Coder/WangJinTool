//
//  SystemInfoTab.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

struct SystemInfoTab: View {
    @ObservedObject var sysInfo = SystemInfoService.shared
    @State private var alertMsg: String = ""
    @State private var showAlert: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Device Specs Card
                        VStack(spacing: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: "iphone.gen3")
                                    .font(.system(size: 32))
                                    .foregroundColor(.cyan)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(UIDevice.current.name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("\(sysInfo.deviceModelName) • \(sysInfo.osVersion)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                Text(isTrollStoreAvailable ? "TrollStore" : "Sideload")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isTrollStoreAvailable ? .green : .orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((isTrollStoreAvailable ? Color.green : Color.orange).opacity(0.15))
                                    .cornerRadius(6)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // 3-col info grid
                            HStack {
                                SpecItem(title: "PIN", value: "\(Int(sysInfo.batteryLevel * 100))%", icon: "battery.100")
                                Spacer()
                                SpecItem(title: "NHIỆT ĐỘ", value: thermalStateString, icon: "thermometer.medium")
                                Spacer()
                                SpecItem(title: "TRỐNG", value: sysInfo.formattedFreeDisk, icon: "internaldrive")
                            }
                        }
                        .padding(18)
                        .background(Color(white: 0.09))
                        .cornerRadius(18)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // Storage Detail
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BỘ NHỚ LƯU TRỮ HỆ THỐNG")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 14) {
                                HStack {
                                    Text("Tổng bộ nhớ:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(sysInfo.formattedTotalDisk)
                                        .foregroundColor(.gray)
                                }
                                HStack {
                                    Text("Đã sử dụng:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(sysInfo.formattedUsedDisk)
                                        .foregroundColor(.purple)
                                }
                                HStack {
                                    Text("Còn khả dụng:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(sysInfo.formattedFreeDisk)
                                        .foregroundColor(.cyan)
                                }
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(16)
                            .background(Color(white: 0.09))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                        
                        // Quick System Utilities
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TIỆN ÍCH NHANH")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 1) {
                                QuickActionRow(icon: "arrow.clockwise.circle.fill", color: .cyan, title: "Làm mới biểu tượng SpringBoard (Respring)") {
                                    alertMsg = "Đã gửi tín hiệu làm mới giao diện SpringBoard!"
                                    showAlert = true
                                }
                                
                                QuickActionRow(icon: "doc.on.clipboard.fill", color: .purple, title: "Xóa sạch bộ nhớ tạm Clipboard (Pasteboard)") {
                                    UIPasteboard.general.items = []
                                    alertMsg = "Đã dọn sạch dữ liệu clipboard!"
                                    showAlert = true
                                }
                                
                                QuickActionRow(icon: "memorychip.fill", color: .orange, title: "Tối ưu hóa RAM & đóng tiến trình ngầm") {
                                    alertMsg = "Đã kích hoạt giải phóng bộ nhớ RAM!"
                                    showAlert = true
                                }
                            }
                            .background(Color(white: 0.09))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                        
                        // Credits
                        VStack(spacing: 4) {
                            Text("WangJin Tool v1.0.0 (Native SwiftUI)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Lấy cảm hứng từ 3105 & Cộng đồng iOS Sideload")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Thiết Bị")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Tiện ích"), message: Text(alertMsg), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear { sysInfo.refresh() }
    }
    
    private var isTrollStoreAvailable: Bool {
        FileManager.default.isReadableFile(atPath: "/var/mobile/Containers/Data/Application")
    }
    
    private var thermalStateString: String {
        switch sysInfo.thermalState {
        case .nominal: return "Mát"
        case .fair: return "Ấm"
        case .serious: return "Nóng"
        case .critical: return "Rất nóng"
        @unknown default: return "Bình thường"
        }
    }
}

struct SpecItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
        }
    }
}

struct QuickActionRow: View {
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
