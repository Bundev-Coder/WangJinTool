//
//  AppBrowserTab.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

struct AppBrowserTab: View {
    @ObservedObject var fileService = FileManagerService.shared
    @State private var searchText: String = ""
    @State private var selectedFilter: AppFilter = .all
    
    enum AppFilter: String, CaseIterable {
        case all = "Tất cả"
        case user = "Người dùng"
        case system = "Hệ thống"
    }
    
    var filteredApps: [AppItem] {
        fileService.apps.filter { app in
            let matchesSearch = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleID.localizedCaseInsensitiveContains(searchText)
            
            switch selectedFilter {
            case .all: return matchesSearch
            case .user: return matchesSearch && !app.isSystem
            case .system: return matchesSearch && app.isSystem
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search & Filter
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Tìm app, bundle identifier...", text: $searchText)
                                .foregroundColor(.white)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        
                        Picker("Bộ lọc", selection: $selectedFilter) {
                            ForEach(AppFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    if fileService.isScanning {
                        Spacer()
                        ProgressView("Đang quét App Containers...")
                            .foregroundColor(.cyan)
                        Spacer()
                    } else if filteredApps.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                            Text("Không tìm thấy ứng dụng nào")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List(filteredApps) { app in
                            NavigationLink(destination: FileExplorerView(title: app.name, currentURL: app.containerURL)) {
                                HStack(spacing: 12) {
                                    Image(systemName: app.isSystem ? "apple.logo" : "app.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(app.isSystem ? .white.opacity(0.8) : .cyan)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(app.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(app.bundleID)
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if app.cacheSize > 0 {
                                        Text(ByteCountFormatter.string(fromByteCount: app.cacheSize, countStyle: .file))
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.cyan.opacity(0.9))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("App Containers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { fileService.scanApps() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
    }
}

// MARK: - File Explorer View
struct FileExplorerView: View {
    let title: String
    let currentURL: URL
    
    @State private var items: [FileItem] = []
    @State private var shareURL: URL?
    @State private var showShareSheet: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Thư mục trống")
                        .foregroundColor(.gray)
                }
            } else {
                List(items) { item in
                    if item.isDirectory {
                        NavigationLink(destination: FileExplorerView(title: item.name, currentURL: item.url)) {
                            FileRow(item: item)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.white.opacity(0.08))
                    } else {
                        FileRow(item: item)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            .contextMenu {
                                Button(action: {
                                    self.shareURL = item.url
                                    self.showShareSheet = true
                                }) {
                                    Label("Chia sẻ / Xuất", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive, action: {
                                    try? FileManager.default.removeItem(at: item.url)
                                    loadItems()
                                }) {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadItems() }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareActivityView(activityItems: [url])
            }
        }
    }
    
    private func loadItems() {
        self.items = FileManagerService.shared.listDirectory(at: currentURL)
    }
}

struct FileRow: View {
    let item: FileItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.name))
                .font(.system(size: 20))
                .foregroundColor(item.isDirectory ? .cyan : .orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(item.formattedSize)
                    if let date = item.modificationDate {
                        Text("•")
                        Text(date, style: .date)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "plist", "json", "xml": return "doc.text.fill"
        case "png", "jpg", "jpeg", "webp": return "photo.fill"
        case "db", "sqlite", "realm": return "cylinder.split.1x2.fill"
        case "zip", "tar", "gz": return "archivebox.fill"
        default: return "doc.fill"
        }
    }
}

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
