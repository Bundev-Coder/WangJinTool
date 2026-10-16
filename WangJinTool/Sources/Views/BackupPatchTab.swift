//
//  BackupPatchTab.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupPatchTab: View {
    @ObservedObject var patchService = PatchManagerService.shared
    @ObservedObject var fileService = FileManagerService.shared

    @State private var searchText: String = ""
    @State private var showDocumentPicker: Bool = false
    @State private var showCreatePatchSheet: Bool = false
    @State private var showPasswordPrompt: Bool = false
    @State private var pendingImportURL: URL?
    @State private var inputPassword: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var shareURL: URL?
    @State private var showShareSheet: Bool = false

    var filteredPatches: [InstalledPatchRecord] {
        if searchText.isEmpty {
            return patchService.installedPatches
        }
        return patchService.installedPatches.filter {
            $0.project.name.localizedCaseInsensitiveContains(searchText) ||
            $0.project.author.localizedCaseInsensitiveContains(searchText) ||
            $0.project.bundleIdentifiers.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Banner
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Quản Lý Gói Bản Vá .3105")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Hỗ trợ định dạng .3105 native & TrollStore")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }

                            // Quick Action Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    triggerHaptic()
                                    showDocumentPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down.fill")
                                        Text("Cài Gói .3105")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(colors: [.cyan, .teal], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    triggerHaptic()
                                    showCreatePatchSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Tạo Bản Vá")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(18)
                        .background(Color(white: 0.08))
                        .cornerRadius(18)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Tìm gói .3105, tác giả, bundle id...", text: $searchText)
                                .foregroundColor(.white)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        // Patches List Header
                        HStack {
                            Text("BẢN VÁ ĐÃ CÀI ĐẶT (\(filteredPatches.count))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Patches Cards
                        if filteredPatches.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("Chưa có gói bản vá .3105 nào")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("Nhấn 'Cài Gói .3105' để nhập từ Tệp (Files) hoặc AirDrop")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(filteredPatches) { record in
                                    PatchCardView(
                                        record: record,
                                        onApply: { applyPatch(record: record) },
                                        onRestore: { restorePatch(record: record) },
                                        onShare: { sharePatch(record: record) },
                                        onDelete: { patchService.deletePatch(record: record) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // App Containers Quick Direct Mod Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ÁNH XẠ CONTAINER ĐANG HOẠT ĐỘNG")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(fileService.apps) { app in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 8, height: 8)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(app.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Text(app.bundleID)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(white: 0.1))
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Bản Vá .3105")
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(supportedContentTypes: [
                    UTType(filenameExtension: "3105") ?? .data,
                    .data,
                    .zip
                ]) { url in
                    handlePickedFile(url: url)
                }
            }
            .sheet(isPresented: $showCreatePatchSheet) {
                CreatePatchSheetView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareActivityView(activityItems: [url])
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Bản Vá .3105"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func handlePickedFile(url: URL) {
        do {
            _ = try patchService.importPackage(from: url)
            alertMessage = "Đã nhập thành công gói bản vá .3105 vào thư viện!"
            showAlert = true
            triggerSuccessHaptic()
        } catch let err as PatchPackageError {
            if case .invalidPassword = err {
                pendingImportURL = url
                showPasswordPrompt = true
            } else {
                alertMessage = "Không thể đọc gói .3105: \(err.localizedDescription)"
                showAlert = true
            }
        } catch {
            alertMessage = "Lỗi khi nhập gói: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func applyPatch(record: InstalledPatchRecord) {
        triggerHaptic()
        do {
            try patchService.applyPatch(record: record)
            alertMessage = "Đã áp dụng bản vá '\(record.project.name)' thành công vào container ứng dụng!"
            showAlert = true
            triggerSuccessHaptic()
        } catch {
            alertMessage = "Không thể áp dụng bản vá: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func restorePatch(record: InstalledPatchRecord) {
        triggerHaptic()
        do {
            try patchService.restorePatch(record: record)
            alertMessage = "Đã khôi phục dữ liệu gốc cho các ứng dụng bị can thiệp."
            showAlert = true
            triggerSuccessHaptic()
        } catch {
            alertMessage = "Lỗi khi khôi phục: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func sharePatch(record: InstalledPatchRecord) {
        if let url = patchService.packageFileURL(for: record) {
            self.shareURL = url
            self.showShareSheet = true
        }
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func triggerSuccessHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Patch Card View
struct PatchCardView: View {
    let record: InstalledPatchRecord
    let onApply: () -> Void
    let onRestore: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Main Summary Header
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.project.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("Tác giả: \(record.project.author)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text(record.isApplied ? "ĐÃ ÁP DỤNG" : "CHƯA ÁP DỤNG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(record.isApplied ? .green : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((record.isApplied ? Color.green : Color.gray).opacity(0.18))
                        .cornerRadius(6)
                }

                // Target Badges
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(record.project.allBundleIdentifiers, id: \.self) { bundleID in
                            Text(bundleID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                }

                HStack {
                    Text("\(record.project.rules.count) quy tắc tệp can thiệp")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Thu gọn" : "Chi tiết tệp")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.cyan)
                    }
                }
            }
            .padding(16)

            // Expanded Rules List
            if isExpanded {
                Divider().background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 8) {
                    Text("ĐƯỜNG DẪN TỆP ÁP DỤNG:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)

                    ForEach(record.project.rules) { rule in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.bundleID)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(rule.relativePath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(rule.replacementData.count), countStyle: .file))
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
            }

            Divider().background(Color.white.opacity(0.08))

            // Action Buttons
            HStack(spacing: 10) {
                if record.isApplied {
                    Button(action: onRestore) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Khôi phục gốc")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    }
                } else {
                    Button(action: onApply) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Áp dụng ngay")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cyan)
                        .cornerRadius(10)
                    }
                }

                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(12)
        }
        .background(Color(white: 0.09))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(record.isApplied ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
    }
}

// MARK: - Document Picker Representable
struct DocumentPickerView: UIViewControllerRepresentable {
    let supportedContentTypes: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

// MARK: - Create Custom Patch Sheet View
struct CreatePatchSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var fileService = FileManagerService.shared

    @State private var patchName: String = ""
    @State private var authorName: String = ""
    @State private var selectedBundleID: String = "com.apple.mobilesafari"
    @State private var relativePath: String = "Library/Preferences/config.plist"
    @State private var payloadContent: String = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>FeatureEnabled</key>\n\t<true/>\n</dict>\n</plist>"
    @State private var password: String = ""
    @State private var statusMsg: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section(header: Text("THÔNG TIN BẢN VÁ").foregroundColor(.gray)) {
                        TextField("Tên bản vá (ví dụ: Tối ưu Shopee)", text: $patchName)
                            .foregroundColor(.white)
                        TextField("Tác giả", text: $authorName)
                            .foregroundColor(.white)
                        SecureField("Mật khẩu bảo vệ gói (Tùy chọn)", text: $password)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color(white: 0.12))

                    Section(header: Text("MỤC TIÊU ÁNH XẠ").foregroundColor(.gray)) {
                        Picker("Ứng dụng", selection: $selectedBundleID) {
                            ForEach(fileService.apps) { app in
                                Text("\(app.name) (\(app.bundleID))").tag(app.bundleID)
                            }
                        }
                        .foregroundColor(.cyan)

                        TextField("Đường dẫn tương đối (ví dụ: Library/Preferences/a.plist)", text: $relativePath)
                            .foregroundColor(.white)
                            .font(.system(.body, design: .monospaced))
                    }
                    .listRowBackground(Color(white: 0.12))

                    Section(header: Text("NỘI DUNG TỆP THAY THẾ (PLIST / JSON / TXT)").foregroundColor(.gray)) {
                        TextEditor(text: $payloadContent)
                            .foregroundColor(.white)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 180)
                    }
                }
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
            }
            .navigationTitle("Tạo Gói .3105 Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng Gói") { packagePatch() }
                        .foregroundColor(.cyan)
                        .font(.headline)
                        .disabled(patchName.trimmingCharacters(in: .whitespaces).isEmpty || relativePath.isEmpty)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Bản Vá"), message: Text(statusMsg), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }

    private func packagePatch() {
        guard let data = payloadContent.data(using: .utf8) else { return }
        let filename = (relativePath as NSString).lastPathComponent
        let rule = PatchRule(
            bundleID: selectedBundleID,
            relativePath: relativePath,
            replacementFilename: filename,
            replacementData: data
        )

        do {
            _ = try PatchManagerService.shared.createNewPatch(
                name: patchName,
                author: authorName,
                password: password.isEmpty ? nil : password,
                rules: [rule]
            )
            statusMsg = "Đã tạo thành công gói bản vá '\(patchName).3105'!"
            showAlert = true
        } catch {
            statusMsg = "Lỗi khi tạo gói: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
