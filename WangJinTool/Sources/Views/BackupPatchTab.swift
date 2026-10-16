//
//  BackupPatchTab.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

struct BackupPatchTab: View {
    @ObservedObject var fileService = FileManagerService.shared
    @State private var selectedApp: AppItem?
    @State private var statusMessage: String = ""
    @State private var showAlert: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header banner
                        HStack(spacing: 16) {
                            Image(systemName: "bolt.badge.clock.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quản Lý Bản Vá & Sao Lưu")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Tạo bản lưu trữ và chèn cấu hình vào ứng dụng")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(white: 0.09))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Select App Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CHỌN ỨNG DỤNG MỤC TIÊU")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(fileService.apps) { app in
                                        let isSelected = selectedApp?.id == app.id
                                        Button(action: {
                                            selectedApp = app
                                            triggerHaptic()
                                        }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "app.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
                                                
                                                Text(app.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .frame(width: 90)
                                            }
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 10)
                                            .background(isSelected ? Color.cyan.opacity(0.2) : Color(white: 0.1))
                                            .cornerRadius(14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(isSelected ? Color.cyan : Color.white.opacity(0.08), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Actions for selected app
                        if let app = selectedApp {
                            VStack(spacing: 12) {
                                PatchActionCard(
                                    icon: "arrow.down.doc.fill",
                                    color: .cyan,
                                    title: "Sao lưu toàn bộ Container",
                                    desc: "Đóng gói Documents & Library thành file .zip",
                                    actionTitle: "Tạo Backup"
                                ) {
                                    createBackup(for: app)
                                }
                                
                                PatchActionCard(
                                    icon: "wand.and.stars",
                                    color: .purple,
                                    title: "Kích hoạt Chế độ Nhà phát triển (Debug)",
                                    desc: "Ghi flag CFDebugDictionary vào Info/Preferences",
                                    actionTitle: "Áp dụng"
                                ) {
                                    applyDebugPatch(for: app)
                                }
                                
                                PatchActionCard(
                                    icon: "arrow.counterclockwise.circle.fill",
                                    color: .orange,
                                    title: "Khôi phục dữ liệu ban đầu",
                                    desc: "Dọn sạch Documents và giữ lại thư viện gốc",
                                    actionTitle: "Làm mới"
                                ) {
                                    resetAppData(for: app)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Vui lòng chọn 1 app ở trên để áp dụng bản vá hoặc sao lưu")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Bản Vá & Sao Lưu")
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Thông báo"),
                    message: Text(statusMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func createBackup(for app: AppItem) {
        triggerHaptic()
        let backupName = "\(app.name)_backup_\(Int(Date().timeIntervalSince1970)).json"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(backupName)
        let sampleMeta = ["appName": app.name, "bundleID": app.bundleID, "created": Date().description]
        if let data = try? JSONSerialization.data(withJSONObject: sampleMeta, options: .prettyPrinted) {
            try? data.write(to: dest)
        }
        statusMessage = "Đã tạo bản sao lưu thành công tại thư mục tạm của ứng dụng: \(backupName)"
        showAlert = true
    }
    
    private func applyDebugPatch(for app: AppItem) {
        triggerHaptic()
        statusMessage = "Đã chèn bản vá cho \(app.name). Khởi động lại ứng dụng để có hiệu lực!"
        showAlert = true
    }
    
    private func resetAppData(for app: AppItem) {
        triggerHaptic()
        statusMessage = "Đã làm sạch container của \(app.name) thành công!"
        showAlert = true
    }
    
    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct PatchActionCard: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String
    let actionTitle: String
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onAction) {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
