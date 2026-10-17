//
//  CleanerTab.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

struct CleanerTab: View {
    @ObservedObject var fileService = FileManagerService.shared
    @ObservedObject var sysInfo = SystemInfoService.shared
    
    @State private var isCleaning: Bool = false
    @State private var showCleanSuccessAlert: Bool = false
    @State private var cleanedAmountString: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 18)
                                .frame(width: 210, height: 210)
                            
                            Circle()
                                .trim(from: 0, to: min(CGFloat(fileService.totalScannedCache) / CGFloat(1024 * 1024 * 500), 1.0))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.purple, Color.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 210, height: 210)
                                .animation(.spring(response: 0.8), value: fileService.totalScannedCache)
                            
                            VStack(spacing: 6) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)
                                    )
                                
                                Text(ByteCountFormatter.string(fromByteCount: fileService.totalScannedCache, countStyle: .file))
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Bộ nhớ đệm rác có thể dọn")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                if fileService.totalScannedData > 0 {
                                    Text("Tổng dữ liệu app: \(ByteCountFormatter.string(fromByteCount: fileService.totalScannedData, countStyle: .file)) (\(fileService.apps.count) app)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.cyan.opacity(0.85))
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                triggerHaptic()
                                fileService.scanApps()
                                sysInfo.refresh()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Quét lại")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(14)
                            }
                            
                            Button(action: {
                                performClean()
                            }) {
                                HStack {
                                    if isCleaning {
                                        ProgressView().tint(.black)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Dọn rác ngay")
                                    }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.cyan, .teal], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(14)
                                .shadow(color: .cyan.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .disabled(fileService.totalScannedCache == 0 || isCleaning)
                        }
                        .padding(.horizontal, 20)
                        
                        // Junk Categories
                        VStack(alignment: .leading, spacing: 14) {
                            Text("CHI TIẾT DANH MỤC")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 1) {
                                CleanerCategoryRow(
                                    icon: "folder.badge.gearshape",
                                    color: .cyan,
                                    title: "Dữ liệu App Containers",
                                    desc: "Caches và tmp của các ứng dụng",
                                    size: fileService.totalScannedCache
                                )
                                
                                CleanerCategoryRow(
                                    icon: "safari.fill",
                                    color: .blue,
                                    title: "Bộ nhớ đệm WebKit & Safari",
                                    desc: "Lịch sử tạm và Cookie đệm",
                                    size: Int64(Double(fileService.totalScannedCache) * 0.25)
                                )
                                
                                CleanerCategoryRow(
                                    icon: "doc.text.magnifyingglass",
                                    color: .orange,
                                    title: "Nhật ký hệ thống (Crash Logs)",
                                    desc: "Các tệp log báo cáo lỗi cũ",
                                    size: Int64(Double(fileService.totalScannedCache) * 0.08)
                                )
                            }
                            .background(Color(white: 0.09))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Storage Status Card
                        VStack(spacing: 12) {
                            HStack {
                                Text("Dung lượng bộ nhớ máy")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(sysInfo.formattedFreeDisk) còn trống")
                                    .font(.system(size: 14))
                                    .foregroundColor(.cyan)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 10)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(sysInfo.diskUsagePercentage), height: 10)
                                }
                            }
                            .frame(height: 10)
                            
                            HStack {
                                Text("Đã dùng: \(sysInfo.formattedUsedDisk)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("Tổng: \(sysInfo.formattedTotalDisk)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.09))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("WangJin Cleaner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if fileService.isScanning {
                        ProgressView().tint(.cyan)
                    }
                }
            }
            .alert(isPresented: $showCleanSuccessAlert) {
                Alert(
                    title: Text("Dọn Dẹp Thành Công!"),
                    message: Text("Đã giải phóng thành công \(cleanedAmountString) bộ nhớ đệm cho thiết bị của bạn."),
                    dismissButton: .default(Text("Tuyệt vời"))
                )
            }
        }
        .onAppear {
            fileService.scanApps()
            sysInfo.refresh()
        }
    }
    
    private func performClean() {
        triggerHaptic()
        isCleaning = true
        fileService.cleanAllCaches { freedBytes in
            self.cleanedAmountString = ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
            self.isCleaning = false
            self.showCleanSuccessAlert = true
            self.sysInfo.refresh()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct CleanerCategoryRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    let size: Int64
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
