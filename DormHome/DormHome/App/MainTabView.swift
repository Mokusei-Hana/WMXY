//
//  MainTabView.swift
//  DormHome
//
//  3 Tab 原生悬浮液态玻璃导航 + 全局 Toast + 登录 Sheet。
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case life
    case settings
}

struct MainTabView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TabView(selection: $model.selectedTab) {
            Tab("首页", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }

            Tab("生活", systemImage: "square.grid.2x2.fill", value: AppTab.life) {
                LifeView()
            }

            Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(AppTheme.actionBlue)
        .fontDesign(.rounded)
        .overlay(alignment: .top) {
            toastOverlay
        }
        .sheet(isPresented: $model.showLogin) {
            LoginSheetView()
        }
    }

    // MARK: - Toast

    private var toastOverlay: some View {
        VStack {
            if let toast = model.toast {
                HStack(spacing: 8) {
                    Image(systemName: toast.style.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(toast.style.tint)
                    Text(toast.message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .glassEffect(.regular, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(AppTheme.glassStroke(scheme: scheme), lineWidth: 0.8)
                }
                .shadow(color: AppTheme.cardShadow(scheme: scheme), radius: 16, y: 6)
                .id(toast.id)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: model.toast)
        .padding(.horizontal, AppTheme.screenPadding)
        .allowsHitTesting(false)
    }
}

#Preview {
    MainTabViewPreview()
}

private struct MainTabViewPreview: View {
    @StateObject private var store = DormStore()
    @StateObject private var model: DormAppModel

    init() {
        let store = DormStore()
        _store = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: DormAppModel(store: store))
    }

    var body: some View {
        MainTabView()
            .environmentObject(store)
            .environmentObject(model)
    }
}
