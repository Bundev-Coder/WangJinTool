//
//  ContentView.swift
//  WangJinTool
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CleanerTab()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Dọn Rác")
                }
                .tag(0)
            
            AppBrowserTab()
                .tabItem {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("Dữ Liệu App")
                }
                .tag(1)
            
            BackupPatchTab()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Bản Vá .3105")
                }
                .tag(2)
            
            SystemInfoTab()
                .tabItem {
                    Image(systemName: "cpu")
                    Text("Thiết Bị")
                }
                .tag(3)
        }
        .accentColor(.cyan)
        .preferredColorScheme(.dark)
    }
}
