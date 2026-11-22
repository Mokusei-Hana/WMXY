//
//  SettingsView.swift
//  DormHome
//
//  账号、外观、门锁体验、生活服务与数据管理。
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    @State private var showSignOutConfirm = false
    @State private var showClearHistoryConfirm = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(state: model.doorState)

                ScrollView {
                    VStack(spacing: AppTheme.moduleSpacing) {
                        header
                        accountCard
                        appearanceCard
                        doorCard
                        modulesCard
                        dataCard
                        aboutCard
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 56)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fontDesign(.rounded)
        .confirmationDialog("退出当前账号？", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                model.signOut()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("清除全部开门记录？", isPresented: $showClearHistoryConfirm, titleVisibility: .visible) {
            Button("清除记录", role: .destructive) {
                store.clearHistory()
                Haptics.notify(.success)
                model.showToast("开门记录已清除", style: .info)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(alignment: .center) {
            Text("设置")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)
                Text(store.sessionStatusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .glassEffect(.regular, in: Capsule(style: .continuous))
        }
    }

    private var statusDotColor: Color {
        if store.isLoggedIn { return AppTheme.onlineGreen }
        if store.isDemoMode { return AppTheme.warningAmber }
        return Color.secondary.opacity(0.6)
    }

    // MARK: - 账号

    private var accountCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: store.isLoggedIn
                                ? [AppTheme.actionCyan, AppTheme.actionBlue]
                                : [Color.secondary.opacity(0.35), Color.secondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                if store.isLoggedIn {
                    Text(accountInitial)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.isLoggedIn ? (store.userName ?? "完美校园用户") : "未登录")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(store.isLoggedIn ? maskedPhone : "登录完美校园以使用门锁与水电")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if store.isLoggedIn {
                Button("切换") {
                    model.openLogin()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            } else {
                Button("登录") {
                    model.openLogin()
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.actionBlue)
                .controlSize(.small)
            }
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }

    private var accountInitial: String {
        if let name = store.userName, let first = name.first {
            return String(first)
        }
        return "宿"
    }

    private var maskedPhone: String {
        guard let phone = store.phone, phone.count == 11 else {
            return "已连接完美校园"
        }
        return phone.prefix(3) + "****" + phone.suffix(4)
    }

    // MARK: - 外观

    private var appearanceCard: some View {
        SettingsCard(title: "外观") {
            HStack(spacing: 8) {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        withAnimation(AppTheme.backgroundEase) {
                            store.setThemeMode(mode)
                        }
                        Haptics.impact(.light)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(mode.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(store.themeMode == mode ? AppTheme.actionBlue : Color.secondary)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(store.themeMode == mode ? AppTheme.actionBlue.opacity(0.13) : Color.primary.opacity(0.035))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    store.themeMode == mode ? AppTheme.actionBlue.opacity(0.4) : Color.clear,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("外观：\(mode.title)")
                }
            }
            .padding(12)
        }
    }

    // MARK: - 门锁与体验

    private var doorCard: some View {
        SettingsCard(title: "门锁与体验") {
            SettingsRow(
                icon: "timer",
                tint: AppTheme.warningAmber,
                title: "自动上锁倒计时",
                subtitle: "开锁后自动恢复上锁状态"
            ) {
                HStack(spacing: 8) {
                    stepButton(symbol: "minus") {
                        store.setAutoRelockSeconds(store.autoRelockSeconds - 5)
                        Haptics.impact(.light)
                    }
                    .disabled(store.autoRelockSeconds <= 10)

                    Text("\(store.autoRelockSeconds) 秒")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .frame(minWidth: 42)

                    stepButton(symbol: "plus") {
                        store.setAutoRelockSeconds(store.autoRelockSeconds + 5)
                        Haptics.impact(.light)
                    }
                    .disabled(store.autoRelockSeconds >= 60)
                }
            }

            if store.isLoggedIn {
                rowDivider
                SettingsRow(
                    icon: "door.left.hand.open",
                    tint: AppTheme.actionBlue,
                    title: "门锁列表",
                    subtitle: "\(store.devices.count) 把可用门锁"
                ) {
                    Button {
                        model.refreshDevices()
                    } label: {
                        if model.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("同步")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(model.isRefreshing || model.isBusy)
                }
            } else {
                rowDivider
                SettingsRow(
                    icon: "sparkles",
                    tint: AppTheme.waterBlue,
                    title: "演示模式",
                    subtitle: "未登录时预览模拟门锁与水电"
                ) {
                    Toggle("", isOn: Binding(
                        get: { store.isDemoMode },
                        set: { enabled in
                            model.setDemoMode(enabled)
                        }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.actionBlue)
                }
            }
        }
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - 模块

    private var modulesCard: some View {
        SettingsCard(title: "生活服务") {
            ForEach(Array(ModuleRegistry.all.enumerated()), id: \.element.id) { index, module in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(module.tint.opacity(0.14))
                        Image(systemName: module.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(module.tint)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(module.title)
                                .font(.system(size: 13, weight: .semibold))
                            if let badge = module.badge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.055)))
                            }
                        }
                        Text(module.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 6)

                    Toggle("", isOn: Binding(
                        get: { store.isModuleEnabled(module.id) },
                        set: { enabled in
                            store.setModule(module.id, enabled: enabled)
                            Haptics.impact(.light)
                        }
                    ))
                    .labelsHidden()
                    .tint(module.tint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if index < ModuleRegistry.all.count - 1 {
                    rowDivider
                }
            }
        }
    }

    // MARK: - 隐私与数据

    private var dataCard: some View {
        SettingsCard(title: "账号与数据") {
            SettingsRow(
                icon: "key.fill",
                tint: AppTheme.campusPurple,
                title: "记住登录状态",
                subtitle: "免去每次重新输入密码"
            ) {
                Toggle("", isOn: Binding(
                    get: { store.rememberCredentials },
                    set: { enabled in
                        store.setRememberCredentials(enabled)
                        Haptics.impact(.light)
                    }
                ))
                .labelsHidden()
                .tint(AppTheme.campusPurple)
            }

            rowDivider

            Button {
                showClearHistoryConfirm = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(AppTheme.dangerRed.opacity(0.12))
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.dangerRed)
                    }
                    .frame(width: 32, height: 32)

                    Text("清除开门记录")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.dangerRed)

                    Spacer()

                    Text("\(store.history.count) 条")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.isLoggedIn {
                rowDivider

                Button {
                    showSignOutConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(AppTheme.dangerRed.opacity(0.12))
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.dangerRed)
                        }
                        .frame(width: 32, height: 32)

                        Text("退出登录")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.dangerRed)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 关于

    private var aboutCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x14203A), Color(hex: 0x0A1626)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.actionCyan, AppTheme.onlineGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("宿享")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("版本 \(version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    // MARK: - 通用

    private var rowDivider: some View {
        Divider()
            .opacity(0.35)
            .padding(.leading, 58)
    }
}

// MARK: - 设置卡片

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)

            VStack(spacing: 0) {
                content
            }
            .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 6)

            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
