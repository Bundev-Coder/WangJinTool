//
//  App.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

@main
struct WangJinToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == "3105" {
                        if PatchManagerService.shared.isPackageProtected(at: url) {
                            PatchManagerService.shared.pendingPasswordProtectedURL = url
                        } else {
                            _ = try? PatchManagerService.shared.importPackage(from: url)
                        }
                    }
                }
        }
    }
}
