//
//  HomeView.swift
//  DormHome
//
//  首页：问候 + 账户状态胶囊 + 液态玻璃门锁主控 + Bento 服务网格。
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return "早上好"
        case 9..<12: return "上午好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<23: return "晚上好"
        default: return "夜深了"
        }
    }

    private var modules: [DormServiceModule] {
        ModuleRegistry.enabled(ids: store.enabledModuleIDs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(state: model.doorState)

                ScrollView {
                    VStack(spacing: AppTheme.moduleSpacing) {
                        header
                        DoorHeroCard()
                        servicesSection
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 56)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationDestination(for: DormServiceModule.self) { module in
                ModuleDestinationView(module: module)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fontDesign(.rounded)
    }

    // MARK: - 顶部栏

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(greeting) · \(store.roomName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("宿享")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 4)

            GlassEffectContainer(spacing: 0) {
                Button {
                    model.openLogin()
                } label: {
                    HStack(spacing: 6) {
                        if store.isLoggedIn {
                            Circle()
                                .fill(AppTheme.onlineGreen)
                                .frame(width: 6, height: 6)
                                .shadow(color: AppTheme.onlineGreen.opacity(0.6), radius: 4)
                            Text(store.userName ?? "已连接")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                        } else if store.isDemoMode {
                            Circle()
                                .fill(AppTheme.warningAmber)
                                .frame(width: 6, height: 6)
                                .shadow(color: AppTheme.warningAmber.opacity(0.6), radius: 4)
                            Text("演示")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.actionBlue)
                            Text("登录")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.actionBlue)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isLoggedIn ? "已登录，轻点切换账号" : "登录完美校园账号")
            }
        }
    }

    // MARK: - 服务网格

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("生活服务")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Button {
                    withAnimation(AppTheme.stateSpring) {
                        model.selectedTab = .life
                    }
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 1) {
                        Text("全部")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if modules.isEmpty {
                emptyModules
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppTheme.tileSpacing),
                        GridItem(.flexible(), spacing: AppTheme.tileSpacing)
                    ],
                    spacing: AppTheme.tileSpacing
                ) {
                    ForEach(modules) { module in
                        ServiceTileView(
                            module: module,
                            value: model.value(for: module),
                            detail: model.detail(for: module)
                        )
                    }
                }
            }
        }
    }

    private var emptyModules: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
            Text("生活服务模块均已关闭")
                .font(.system(size: 14, weight: .medium))
            Text("可在「设置 · 生活服务」中重新开启")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }
}

#Preview {
    HomeViewPreview()
}

private struct HomeViewPreview: View {
    @StateObject private var store = DormStore()
    @StateObject private var model: DormAppModel

    init() {
        let store = DormStore()
        _store = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: DormAppModel(store: store))
    }

    var body: some View {
        HomeView()
            .environmentObject(store)
            .environmentObject(model)
    }
}
