//
//  SettingsView.swift
//  DormHome
//
//  账号与登录态、设备 ID、外观、模块开关、安全设置。
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    @State private var showSignOutConfirm = false
    @State private var showClearHistoryConfirm = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(state: model.doorState)

                ScrollView {
                    VStack(spacing: AppTheme.moduleSpacing) {
                        header
                        accountCard
                        sessionCard
                        deviceCard
                        appearanceCard
                        doorCard
                        modulesCard
                        securityCard
                        aboutCard
                        footerNote
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
        .confirmationDialog("退出完美校园账号？", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                model.signOut()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后将回到演示模式，本机设备 ID 与开门记录会保留。")
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
            VStack(alignment: .leading, spacing: 3) {
                Text("账号、外观与设备偏好")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("设置")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(store.isLoggedIn ? AppTheme.onlineGreen : AppTheme.warningAmber)
                    .frame(width: 6, height: 6)
                Text(store.isLoggedIn ? "已连接" : "演示模式")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .glassEffect(.regular, in: Capsule(style: .continuous))
        }
    }

    // MARK: - 账号

    private var accountCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.actionCyan, AppTheme.actionBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(accountInitial)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: AppTheme.actionBlue.opacity(0.25), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.isLoggedIn ? (store.userName ?? "完美校园用户") : "演示访客")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(store.isLoggedIn ? maskedPhone : "登录后连接真实宿舍门锁")
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
            return store.isLoggedIn ? "已连接完美校园" : "演示模式"
        }
        return phone.prefix(3) + "****" + phone.suffix(4)
    }

    // MARK: - 会话

    private var sessionCard: some View {
        SettingsCard(title: "登录态") {
            SettingsRow(icon: "checkmark.seal.fill", tint: store.isLoggedIn ? AppTheme.onlineGreen : AppTheme.warningAmber, title: "会话状态", subtitle: nil) {
                Text(store.isLoggedIn ? "有效 · \(store.sessionAgeText)" : "未登录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            rowDivider
            SettingsRow(icon: "number", tint: AppTheme.actionBlue, title: "outid", subtitle: nil) {
                Text(store.outid ?? "—")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            rowDivider
            SettingsRow(icon: "key.horizontal.fill", tint: AppTheme.campusPurple, title: "会话 ID", subtitle: nil) {
                Text(store.sessionShortID)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 设备 ID

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.waterBlue.opacity(0.14))
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.waterBlue)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("本机设备 ID")
                        .font(.system(size: 14, weight: .semibold))
                    Text(store.deviceId)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)

                Button {
                    UIPasteboard.general.string = store.deviceId
                    Haptics.impact(.light)
                    model.showToast("设备 ID 已复制", style: .success)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("复制设备 ID")
            }

            Text("设备 ID 首次生成后保持不变。更换设备 ID 会触发完美校园「新设备登录」短信验证。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    // MARK: - 外观

    private var appearanceCard: some View {
        SettingsCard(title: "外观") {
            VStack(spacing: 12) {
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

                Text("外观切换立即生效，并同步影响背景氛围光与玻璃材质。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }

    // MARK: - 门锁

    private var doorCard: some View {
        SettingsCard(title: "门锁体验") {
            SettingsRow(
                icon: "timer",
                tint: AppTheme.warningAmber,
                title: "自动回锁倒计时",
                subtitle: "开锁成功后自动复位的演示时长"
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
                        .frame(minWidth: 44)

                    stepButton(symbol: "plus") {
                        store.setAutoRelockSeconds(store.autoRelockSeconds + 5)
                        Haptics.impact(.light)
                    }
                    .disabled(store.autoRelockSeconds >= 60)
                }
            }
            rowDivider
            SettingsRow(
                icon: "door.left.hand.open",
                tint: AppTheme.actionBlue,
                title: "门锁列表",
                subtitle: store.isLoggedIn ? "\(store.devices.count) 把已授权门锁" : "演示门锁 · 3栋 412"
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
                        Text(module.title)
                            .font(.system(size: 13, weight: .semibold))
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

    // MARK: - 安全

    private var securityCard: some View {
        SettingsCard(title: "安全与隐私") {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.campusPurple.opacity(0.14))
                    Image(systemName: "key.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.campusPurple)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("保存登录凭证")
                        .font(.system(size: 13, weight: .semibold))
                    Text("仅保存在本机 Keychain，用于会话失效时自动续登")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

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
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

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
        }
    }

    // MARK: - 关于

    private var aboutCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x14203A), Color(hex: 0x0A1626)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.actionCyan, AppTheme.onlineGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("宿享")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("DormHome · \(version) (\(build))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("iOS 26")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.055)))
            }
            .padding(16)

            rowDivider

            VStack(alignment: .leading, spacing: 8) {
                Text("基于完美校园开放协议实现，远程指令仅用于本人账号与本人已授权门禁设备。本应用不收集、不上传任何个人数据；门锁列表与操作记录仅保存在本机。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    private var footerNote: some View {
        VStack(spacing: 4) {
            Text("Made for dorm life")
                .font(.system(size: 10, weight: .medium))
            Text("请遵守学校门禁管理规定")
                .font(.system(size: 10))
        }
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
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
