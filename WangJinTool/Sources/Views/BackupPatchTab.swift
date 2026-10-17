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
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var shareURL: URL?
    @State private var showShareSheet: Bool = false

    @State private var selectedPatchForConfig: InstalledPatchRecord?
    @State private var showForceCloseAlert: Bool = false
    @State private var forceCloseAppName: String = ""

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

                        // TrollStore Root Access Banner if not detected
                        if !fileService.hasTrollStoreRootAccess {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 20))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Chưa phát hiện quyền Root Container")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.yellow)
                                    Text("Để áp dụng bản vá trực tiếp vào thư mục game/ứng dụng, bạn cần cài đặt WangJinTool qua TrollStore (No-Sandbox).")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(14)
                            .background(Color.yellow.opacity(0.12))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }

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
                                        onConfigure: {
                                            selectedPatchForConfig = record
                                        },
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
            .sheet(item: $selectedPatchForConfig) { rec in
                PatchConfigSheetView(
                    record: rec,
                    onApplied: { appName in
                        forceCloseAppName = appName
                        showForceCloseAlert = true
                    }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareActivityView(activityItems: [url])
                }
            }
            .sheet(isPresented: $showPasswordPrompt) {
                PasswordUnlockSheetView(
                    targetURL: pendingImportURL,
                    onUnlock: { pwd in unlockAndImport(password: pwd) },
                    onCancel: {
                        showPasswordPrompt = false
                        pendingImportURL = nil
                        patchService.pendingPasswordProtectedURL = nil
                    }
                )
            }
            .onReceive(patchService.$pendingPasswordProtectedURL) { incomingURL in
                if let url = incomingURL {
                    pendingImportURL = url
                    showPasswordPrompt = true
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Bản Vá .3105"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showForceCloseAlert) {
                Alert(
                    title: Text("Áp Dụng Bản Vá Thành Công!"),
                    message: Text("Đã ghi đè các tệp cấu hình vào container của '\(forceCloseAppName)'.\n\n⚠️ LƯU Ý BẮT BUỘC:\nHãy vuốt từ đáy màn hình lên để mở Trình Đa Nhiệm (App Switcher), VUỐT TẮT ứng dụng '\(forceCloseAppName)' và mở lại để iOS nạp cấu hình mới!"),
                    dismissButton: .default(Text("Đã Hiểu"))
                )
            }
        }
    }

    private func handlePickedFile(url: URL) {
        if patchService.isPackageProtected(at: url) {
            pendingImportURL = url
            showPasswordPrompt = true
            return
        }

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

    private func unlockAndImport(password: String) {
        guard let url = pendingImportURL else { return }
        do {
            _ = try patchService.importPackage(from: url, password: password)
            showPasswordPrompt = false
            pendingImportURL = nil
            patchService.pendingPasswordProtectedURL = nil
            alertMessage = "Đã mở khóa và cài đặt thành công gói bản vá .3105!"
            showAlert = true
            triggerSuccessHaptic()
        } catch {
            alertMessage = "Mật khẩu không đúng: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func applyPatch(record: InstalledPatchRecord) {
        triggerHaptic()
        do {
            try patchService.applyPatch(record: record)
            let targetNames = record.project.allBundleIdentifiers.compactMap { bId in
                fileService.apps.first(where: { $0.bundleID == bId })?.name ?? bId
            }.joined(separator: ", ")
            forceCloseAppName = targetNames.isEmpty ? record.project.name : targetNames
            showForceCloseAlert = true
            triggerSuccessHaptic()
        } catch {
            alertMessage = "Không thể áp dụng bản vá: \(error.localizedDescription)\n\nHãy nhấn nút 'Cấu hình' trên thẻ bản vá để kiểm tra hoặc chọn lại ứng dụng mục tiêu."
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
    let onConfigure: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded: Bool = false

    private var isContainerResolved: Bool {
        guard !record.project.allBundleIdentifiers.isEmpty else { return false }
        return record.project.allBundleIdentifiers.allSatisfy { id in
            PatchManagerService.shared.resolveContainer(for: id) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main Summary Header
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(record.project.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            if record.project.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.yellow)
                            }
                        }

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

                // Container Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(isContainerResolved ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)

                    Text(isContainerResolved ? "Đã tìm thấy app đích trên máy" : "Chưa khớp app trên máy (Bấm 'Cấu hình' để đổi)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isContainerResolved ? .green : .orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((isContainerResolved ? Color.green : Color.orange).opacity(0.08))
                .cornerRadius(6)

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
                            Text("Khôi phục")
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
                            Text("Áp dụng")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cyan)
                        .cornerRadius(10)
                    }
                }

                Button(action: onConfigure) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Cấu hình")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(10)
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

// MARK: - Patch Configuration & Remapping Sheet
struct PatchConfigSheetView: View {
    let record: InstalledPatchRecord
    let onApplied: ((String) -> Void)?

    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var patchService = PatchManagerService.shared
    @ObservedObject var fileService = FileManagerService.shared

    @State private var selectedBundleID: String = ""
    @State private var customBundleID: String = ""
    @State private var isCustomApp: Bool = false
    @State private var rules: [PatchRule] = []

    @State private var selectedRuleForEdit: PatchRule? = nil
    @State private var showAddRuleSheet: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    var currentTargetBundleID: String {
        if isCustomApp {
            return customBundleID.trimmingCharacters(in: .whitespaces)
        }
        return selectedBundleID
    }

    var resolvedContainerURL: URL? {
        patchService.resolveContainer(for: currentTargetBundleID)
    }

    init(record: InstalledPatchRecord, onApplied: ((String) -> Void)? = nil) {
        self.record = record
        self.onApplied = onApplied
        let initialBundle = record.project.bundleIdentifiers.first ?? (record.project.rules.first?.bundleID ?? "")
        _selectedBundleID = State(initialValue: initialBundle)
        _customBundleID = State(initialValue: initialBundle)
        _rules = State(initialValue: record.project.rules)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Section 1: Patch Info Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BẢN VÁ: \(record.project.name.uppercased())")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.project.name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Tác giả: \(record.project.author)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if record.project.isPrivate {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill")
                                        Text("AES-256")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.15))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Section 2: Target App Remapping
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("ỨNG DỤNG MỤC TIÊU (CONTAINER)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: { isCustomApp.toggle() }) {
                                    Text(isCustomApp ? "Chọn từ danh sách" : "Tự nhập Bundle ID")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.cyan)
                                }
                            }

                            if !isCustomApp {
                                if fileService.apps.isEmpty {
                                    VStack(spacing: 8) {
                                        Text("Chưa tìm thấy danh sách app từ máy")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                        Button(action: { fileService.scanApps() }) {
                                            Text("Quét lại danh sách ứng dụng")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Color(white: 0.08))
                                    .cornerRadius(10)
                                } else {
                                    Picker("Chọn Ứng Dụng", selection: $selectedBundleID) {
                                        ForEach(fileService.apps) { app in
                                            Text("\(app.name) (\(app.bundleID))").tag(app.bundleID)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(white: 0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            } else {
                                TextField("Nhập Bundle ID (ví dụ: com.dts.freefirevn)", text: $customBundleID)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(white: 0.12))
                                    .cornerRadius(10)
                            }

                            // Real-time Container Status Box
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: resolvedContainerURL != nil ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                    .foregroundColor(resolvedContainerURL != nil ? .green : .red)
                                    .font(.system(size: 16))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(resolvedContainerURL != nil ? "ĐÃ TÌM THẤY CONTAINER TRÊN THIẾT BỊ" : "CHƯA TÌM THẤY CONTAINER CỦA APP NÀY")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(resolvedContainerURL != nil ? .green : .red)

                                    if let url = resolvedContainerURL {
                                        Text(url.path)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                            .lineLimit(2)
                                    } else {
                                        Text("Hãy đảm bảo bạn đã cài đặt ứng dụng này trên máy, hoặc chọn lại đúng phiên bản khu vực (VD: bản VN thay vì bản Quốc tế/Thái).")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background((resolvedContainerURL != nil ? Color.green : Color.red).opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(16)
                        .background(Color(white: 0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 16)

                        // Section 3: Rules & Config File Payloads
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("CÁC TỆP CẤU HÌNH THAY THẾ (\(rules.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: { showAddRuleSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Thêm tệp")
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.cyan)
                                }
                            }

                            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.orange)
                                        Text(rule.relativePath)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(rule.replacementData.count), countStyle: .file))
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }

                                    HStack(spacing: 12) {
                                        Button(action: {
                                            selectedRuleForEdit = rule
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "pencil")
                                                Text("Xem & Sửa Giá Trị")
                                            }
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.cyan)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.cyan.opacity(0.15))
                                            .cornerRadius(8)
                                        }

                                        Spacer()

                                        Button(action: {
                                            rules.remove(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red.opacity(0.8))
                                                .padding(6)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(white: 0.12))
                                .cornerRadius(10)
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 16)

                        // Section 4: Action Buttons
                        VStack(spacing: 10) {
                            Button(action: {
                                saveAndApply()
                            }) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                    Text("Lưu & Áp Dụng Ngay Vào Ứng Dụng")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.cyan, .teal], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(12)
                            }

                            Button(action: {
                                saveConfigOnly()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Chỉ Lưu Cấu Hình")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Tùy Chỉnh Cấu Hình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .sheet(item: $selectedRuleForEdit) { rule in
                RuleContentEditorSheetView(rule: rule) { updatedRule in
                    if let idx = rules.firstIndex(where: { $0.id == updatedRule.id }) {
                        rules[idx] = updatedRule
                    }
                }
            }
            .sheet(isPresented: $showAddRuleSheet) {
                AddRuleSheetView(targetBundleID: currentTargetBundleID) { newRule in
                    rules.append(newRule)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Cấu Hình"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func saveConfigOnly() {
        let target = currentTargetBundleID
        patchService.updatePatch(record: record, targetBundleID: target, updatedRules: rules)
        alertMessage = "Đã lưu thành công cấu hình bản vá cho ứng dụng '\(target)'!"
        showAlert = true
    }

    private func saveAndApply() {
        let target = currentTargetBundleID
        patchService.updatePatch(record: record, targetBundleID: target, updatedRules: rules)

        // Find refreshed record
        guard let updatedRecord = patchService.installedPatches.first(where: { $0.id == record.id }) else { return }

        do {
            try patchService.applyPatch(record: updatedRecord)
            let appName = fileService.apps.first(where: { $0.bundleID == target })?.name ?? target
            presentationMode.wrappedValue.dismiss()
            onApplied?(appName)
        } catch {
            alertMessage = "Lỗi khi áp dụng: \(error.localizedDescription)\n\nVui lòng kiểm tra lại đường dẫn container hoặc Bundle ID của app."
            showAlert = true
        }
    }
}

// MARK: - Rule Content Editor Sheet View
struct RuleContentEditorSheetView: View {
    let rule: PatchRule
    let onSave: (PatchRule) -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var textContent: String = ""
    @State private var isBinary: Bool = false

    init(rule: PatchRule, onSave: @escaping (PatchRule) -> Void) {
        self.rule = rule
        self.onSave = onSave
        if let str = String(data: rule.replacementData, encoding: .utf8) {
            _textContent = State(initialValue: str)
            _isBinary = State(initialValue: false)
        } else {
            _textContent = State(initialValue: "Tệp nhị phân (\(rule.replacementData.count) bytes) không thể hiển thị dưới dạng văn bản thô.")
            _isBinary = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.relativePath)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("Kích thước: \(rule.replacementData.count) bytes | \(isBinary ? "Tệp nhị phân" : "Văn bản (UTF-8)")")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    TextEditor(text: $textContent)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(white: 0.1))
                        .cornerRadius(10)
                        .disabled(isBinary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Chỉnh Sửa Tệp Cấu Hình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        if !isBinary, let newData = textContent.data(using: .utf8) {
                            var modified = rule
                            modified.replacementData = newData
                            onSave(modified)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.cyan)
                    .font(.headline)
                    .disabled(isBinary)
                }
            }
        }
    }
}

// MARK: - Add Rule Sheet View
struct AddRuleSheetView: View {
    let targetBundleID: String
    let onAdd: (PatchRule) -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var relativePath: String = "Library/Preferences/config.plist"
    @State private var payloadContent: String = "{\n  \"enabled\": true\n}"

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section(header: Text("ĐƯỜNG DẪN TỆP TRONG CONTAINER").foregroundColor(.gray)) {
                        TextField("Đường dẫn tương đối (ví dụ: Documents/file.json)", text: $relativePath)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color(white: 0.12))

                    Section(header: Text("NỘI DUNG TỆP").foregroundColor(.gray)) {
                        TextEditor(text: $payloadContent)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(height: 180)
                    }
                    .listRowBackground(Color(white: 0.12))
                }
            }
            .navigationTitle("Thêm Tệp Quy Tắc Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Thêm") {
                        let filename = (relativePath as NSString).lastPathComponent
                        let data = payloadContent.data(using: .utf8) ?? Data()
                        let newRule = PatchRule(
                            bundleID: targetBundleID,
                            relativePath: relativePath,
                            replacementFilename: filename,
                            replacementData: data
                        )
                        onAdd(newRule)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.cyan)
                    .font(.headline)
                    .disabled(relativePath.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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

// MARK: - Password Unlock Sheet View
struct PasswordUnlockSheetView: View {
    let targetURL: URL?
    let onUnlock: (String) -> Void
    let onCancel: () -> Void

    @State private var passwordText: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.yellow.opacity(0.2), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    }
                    .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("Gói Bản Vá Được Khóa")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Tệp .3105 này được bảo vệ bằng mật khẩu mã hóa AES-256. Vui lòng nhập mật khẩu mở khóa do tác giả cung cấp.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Password Input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isPasswordVisible {
                                TextField("Nhập mật khẩu mở khóa...", text: $passwordText)
                                    .foregroundColor(.white)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Nhập mật khẩu mở khóa...", text: $passwordText)
                                    .foregroundColor(.white)
                            }

                            Button(action: { isPasswordVisible.toggle() }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Action Button
                    Button(action: {
                        if passwordText.trimmingCharacters(in: .whitespaces).isEmpty {
                            errorMessage = "Vui lòng nhập mật khẩu!"
                            return
                        }
                        errorMessage = ""
                        onUnlock(passwordText)
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Mở Khóa & Cài Đặt")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { onCancel() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
