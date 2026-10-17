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
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.cyan)
                            Text("Đang quét toàn bộ ứng dụng và dữ liệu container...")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else if filteredApps.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                            Text("Không tìm thấy ứng dụng nào")
                                .foregroundColor(.gray)
                            Button(action: { fileService.scanApps() }) {
                                Text("Quét lại ngay")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
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
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if app.totalSize > 0 {
                                            Text(app.formattedTotalSize)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        if app.cacheSize > 0 {
                                            Text("Rác: \(app.formattedCacheSize)")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundColor(.cyan.opacity(0.8))
                                        }
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
            .navigationTitle("Dữ Liệu Ứng Dụng")
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
    @State private var selectedFileForView: FileItem? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Current Path Banner
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 12))
                    Text(currentURL.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))

                if items.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Thư mục trống")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List(items) { item in
                        if item.isDirectory {
                            NavigationLink(destination: FileExplorerView(title: item.name, currentURL: item.url)) {
                                FileRow(item: item)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                        } else {
                            Button(action: {
                                selectedFileForView = item
                            }) {
                                FileRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            .contextMenu {
                                Button(action: {
                                    self.selectedFileForView = item
                                }) {
                                    Label("Xem nội dung tệp", systemImage: "doc.text.magnifyingglass")
                                }
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
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { loadItems() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.cyan)
                }
            }
        }
        .onAppear { loadItems() }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareActivityView(activityItems: [url])
            }
        }
        .sheet(item: $selectedFileForView) { item in
            FileViewerSheetView(fileItem: item)
        }
    }
    
    private func loadItems() {
        self.items = FileManagerService.shared.listDirectory(at: currentURL)
    }
}

// MARK: - File Row
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
        case "plist", "json", "xml", "txt", "cfg", "ini": return "doc.text.fill"
        case "png", "jpg", "jpeg", "webp", "gif": return "photo.fill"
        case "db", "sqlite", "realm": return "cylinder.split.1x2.fill"
        case "zip", "tar", "gz", "3105": return "archivebox.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - File Viewer Sheet View
struct FileViewerSheetView: View {
    let fileItem: FileItem
    @Environment(\.presentationMode) var presentationMode
    @State private var contentString: String = ""
    @State private var isBinary: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fileItem.name)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("\(fileItem.formattedSize) • \(isBinary ? "Tệp nhị phân" : "Văn bản UTF-8")")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if isBinary {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.zipper")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                            Text("Tệp nhị phân không hỗ trợ xem dưới dạng văn bản.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            Text(contentString)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(white: 0.08))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Nội Dung Tệp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .onAppear {
                loadFileContent()
            }
        }
    }

    private func loadFileContent() {
        if let data = try? Data(contentsOf: fileItem.url) {
            if let str = String(data: data, encoding: .utf8) {
                self.contentString = str
                self.isBinary = false
            } else if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                      let jsonData = try? JSONSerialization.data(withJSONObject: plist, options: [.prettyPrinted]),
                      let jsonString = String(data: jsonData, encoding: .utf8) {
                self.contentString = jsonString
                self.isBinary = false
            } else {
                self.isBinary = true
            }
        }
    }
}
