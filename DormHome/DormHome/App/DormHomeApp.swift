//
//  DormHomeApp.swift
//  DormHome
//
//  宿享 · 智能宿舍生活
//

import SwiftUI

@main
struct DormHomeApp: App {
    @StateObject private var store: DormStore
    @StateObject private var model: DormAppModel

    init() {
        let store = DormStore()
        _store = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: DormAppModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(model)
                .preferredColorScheme(store.themeMode.colorScheme)
                .tint(AppTheme.actionBlue)
        }
    }
}
