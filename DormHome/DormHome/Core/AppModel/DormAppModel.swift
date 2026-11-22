//
//  DormAppModel.swift
//  DormHome
//
//  门锁交互状态机、登录流程与演示模式。
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Toast

struct ToastMessage: Identifiable, Equatable {
    enum Style {
        case success
        case info
        case error

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "sparkles"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success: return AppTheme.onlineGreen
            case .info: return AppTheme.actionBlue
            case .error: return AppTheme.dangerRed
            }
        }
    }

    let id = UUID()
    var message: String
    var style: Style
}

// MARK: - 触觉

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - App Model

@MainActor
final class DormAppModel: ObservableObject {

    let store: DormStore
    private let client = WMXYClient()
    private let swae = SWAEClient()

    @Published var selectedTab: AppTab = .home
    @Published var doorState: DoorVisualState = .locked
    @Published var selectedDeviceID: String?
    @Published var isBusy = false
    @Published var isRefreshing = false
    @Published var unlockCountdown: Int?
    @Published var showLogin = false
    @Published var loginNotice: String?
    @Published var toast: ToastMessage?
    @Published var lastOperationText: String?

    // MARK: 水电状态
    @Published var isUtilitiesLoading = false
    @Published var utilitiesError: String?
    @Published var utilityConfig: SWAEConfig?

    private var isSessionReady = false
    private var relockTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var operationStartedAt: Date?

    init(store: DormStore) {
        self.store = store
        self.selectedDeviceID = store.devices.first?.deviceId
        if store.isLoggedIn, let outid = store.outid, !outid.isEmpty {
            Task { @MainActor [weak self] in
                await self?.refreshUtilities(silent: true)
            }
        }
    }

    deinit {
        relockTask?.cancel()
        toastTask?.cancel()
    }

    // MARK: 派生状态

    var devices: [DoorDevice] { store.devices }

    var selectedDevice: DoorDevice? {
        if let selectedDeviceID,
           let match = store.devices.first(where: { $0.deviceId == selectedDeviceID }) {
            return match
        }
        return store.devices.first
    }

    var isUnlocked: Bool { doorState == .unlocked }

    var relockTotal: Int { max(1, store.autoRelockSeconds) }

    var relockProgress: Double {
        guard let unlockCountdown else { return 0 }
        return 1 - Double(unlockCountdown) / Double(relockTotal)
    }

    var statusLabel: String {
        switch doorState {
        case .locked:
            return "轻触开锁"
        case .unlocking:
            return "开锁中…"
        case .unlocked:
            if let unlockCountdown {
                return "已开锁 · \(unlockCountdown)s"
            }
            return "已开锁"
        }
    }

    var microStatus: String? {
        if let lastOperationText, !lastOperationText.isEmpty {
            return lastOperationText
        }
        if store.isDemoMode {
            return "演示模式 · 仅模拟开锁"
        }
        return nil
    }

    // MARK: 开锁 / 上锁

    func unlock() {
        guard !isBusy, doorState != .unlocking else { return }
        if !store.isLoggedIn && !store.isDemoMode {
            openLogin()
            return
        }
        guard let device = selectedDevice else {
            showToast("未找到可用门锁，请尝试刷新", style: .error)
            return
        }
        guard device.isOnline else {
            Haptics.notify(.error)
            showToast("门锁当前离线", style: .error)
            return
        }

        Haptics.impact(.medium)
        operationStartedAt = Date()
        lastOperationText = nil
        withAnimation(AppTheme.stateSpring) {
            doorState = .unlocking
        }
        isBusy = true

        Task { @MainActor in
            do {
                let successMessage: String
                if store.isLoggedIn {
                    try await prepareSession()
                    _ = try await client.openDoor(device)
                    successMessage = "开锁成功"
                } else {
                    try await Task.sleep(nanoseconds: 900_000_000)
                    successMessage = "演示开锁成功"
                }

                withAnimation(AppTheme.stateSpring) {
                    doorState = .unlocked
                }
                Haptics.notify(.success)

                store.record(UnlockRecord(
                    deviceID: device.deviceId,
                    deviceName: device.name,
                    action: .unlock,
                    channel: store.isLoggedIn ? .remote : .demo,
                    detail: successMessage,
                    isDemo: !store.isLoggedIn
                ))
                lastOperationText = successMessage
                startRelockCountdown()
            } catch {
                withAnimation(AppTheme.stateSpring) {
                    doorState = .locked
                }
                handleFailure(error)
            }
            isBusy = false
        }
    }

    func lock(auto: Bool = false) {
        stopRelockCountdown()
        Haptics.impact(.light)
        withAnimation(AppTheme.stateSpring) {
            doorState = .locked
        }
        unlockCountdown = nil

        let device = selectedDevice
        if let device {
            store.record(UnlockRecord(
                deviceID: device.deviceId,
                deviceName: device.name,
                action: .lock,
                channel: auto ? .autoRelock : .local,
                detail: auto ? "自动上锁" : "手动上锁",
                isDemo: !store.isLoggedIn
            ))
        }
        lastOperationText = auto ? "已自动上锁" : "已手动上锁"
        if auto {
            Haptics.notify(.success)
        }
    }

    func toggleDoor() {
        if doorState == .unlocked {
            lock()
        } else {
            unlock()
        }
    }

    func selectDevice(_ device: DoorDevice) {
        guard device.deviceId != selectedDeviceID else { return }
        if doorState == .unlocked {
            lock()
        }
        selectedDeviceID = device.deviceId
        Haptics.impact(.light)
        withAnimation(AppTheme.stateSpring) {
            doorState = .locked
        }
    }

    private func startRelockCountdown() {
        stopRelockCountdown()
        let total = relockTotal
        unlockCountdown = total
        relockTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var remaining = total
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
                withAnimation(.linear(duration: 0.22)) {
                    self.unlockCountdown = remaining
                }
            }
            if !Task.isCancelled {
                self.lock(auto: true)
            }
        }
    }

    private func stopRelockCountdown() {
        relockTask?.cancel()
        relockTask = nil
    }

    // MARK: 刷新

    func refreshDevices() {
        guard !isRefreshing, !isBusy else { return }
        isRefreshing = true
        Task { @MainActor in
            defer { isRefreshing = false }
            if store.isLoggedIn {
                do {
                    try await prepareSession()
                    let list = try await client.fetchDevicesAfterLogin()
                    store.updateDevices(list)
                    if selectedDevice == nil {
                        selectedDeviceID = list.first?.deviceId
                    }
                    showToast("门锁列表已同步 · \(list.count) 把", style: .success)
                    Haptics.notify(.success)
                } catch {
                    handleFailure(error)
                }
            } else if store.isDemoMode {
                try? await Task.sleep(nanoseconds: 500_000_000)
                showToast("门锁状态已刷新", style: .info)
            } else {
                openLogin()
            }
        }
    }

    // MARK: 实时水电

    var utilityAccount: String { store.outid ?? "" }
    var hasLiveUtilities: Bool { store.roomDetail != nil }
    var utilityDataStateLabel: String { hasLiveUtilities ? "实时数据" : "演示数据" }

    func scheduleUtilitiesRefresh() {
        Task { @MainActor [weak self] in
            await self?.refreshUtilities(silent: true)
        }
    }

    /// 登录 / 复用会话 / 进入页面时静默刷新。失败只更新错误文案，不阻断开门。
    func refreshUtilities(silent: Bool = false) async {
        guard !isUtilitiesLoading else { return }
        isUtilitiesLoading = true
        defer { isUtilitiesLoading = false }

        let account = utilityAccount
        do {
            let rooms = try await swae.fetchBoundRooms(account: account)
            store.applyBoundRooms(rooms)

            if let verify = store.selectedRoomVerify, !verify.isEmpty {
                do {
                    let detail = try await swae.fetchRoomDetail(roomverify: verify, account: account)
                    store.applyRoomDetail(detail)
                } catch {
                    // 手动选中的房间不属于当前绑定列表时，回退到第一个已绑定房间。
                    if !rooms.contains(where: { $0.roomVerify == verify }),
                       let fallback = rooms.first {
                        let detail = try await swae.fetchRoomDetail(
                            roomverify: fallback.roomVerify,
                            account: account
                        )
                        store.selectUtilityRoom(fallback)
                        store.applyRoomDetail(detail)
                    } else {
                        throw error
                    }
                }
            } else {
                store.markUtilitySynced()
            }

            utilitiesError = nil
            if !silent {
                Haptics.notify(.success)
                showToast("水电数据已更新", style: .success)
            }
        } catch {
            let message = utilityMessage(for: error)
            utilitiesError = message
            if !silent {
                Haptics.notify(.error)
                showToast("水电同步失败 · \(message)", style: .error)
            }
        }

        if let config = try? await swae.fetchH5Config(account: account) {
            utilityConfig = config
        }
    }

    func selectUtilityRoom(_ room: SWAERoomSummary) {
        store.selectUtilityRoom(room)
        Task { @MainActor [weak self] in
            await self?.reloadSelectedRoom(announce: true)
        }
    }

    private func reloadSelectedRoom(announce: Bool) async {
        guard !isUtilitiesLoading else { return }
        guard let verify = store.selectedRoomVerify, !verify.isEmpty else {
            if announce { showToast("请先选择宿舍房间", style: .info) }
            return
        }

        isUtilitiesLoading = true
        defer { isUtilitiesLoading = false }

        do {
            let detail = try await swae.fetchRoomDetail(roomverify: verify, account: utilityAccount)
            store.applyRoomDetail(detail)
            utilitiesError = nil
            if announce {
                Haptics.notify(.success)
                showToast("已更新 \(detail.roomFullName)", style: .success)
            }
        } catch {
            let message = utilityMessage(for: error)
            utilitiesError = message
            if announce {
                Haptics.notify(.error)
                showToast("水电查询失败 · \(message)", style: .error)
            }
        }
    }

    /// 手动级联选房：成功后立即查询该房间实时水电。
    func selectUtilityRoom(
        room: SWAERoomOption,
        zone: SWAEZone,
        building: SWAEBuilding,
        floor: SWAEFloor
    ) async throws {
        guard !isUtilitiesLoading else { return }
        isUtilitiesLoading = true
        defer { isUtilitiesLoading = false }

        do {
            let preferredVerify = store.boundRooms.first {
                UtilityRoomName.matches(bound: $0.roomFullName, selected: room.name)
            }?.roomVerify
            let detail = try await swae.fetchRoomDetail(
                room: room,
                zoneID: zone.id,
                buildID: building.id,
                floorID: floor.id,
                preferredVerify: preferredVerify,
                account: utilityAccount
            )
            store.selectUtilityRoom(roomVerify: detail.roomVerify, name: detail.roomFullName)
            store.applyRoomDetail(detail)
            utilitiesError = nil
            Haptics.notify(.success)
            showToast("已切换 · \(detail.roomFullName)", style: .success)
        } catch {
            let message = utilityMessage(for: error)
            utilitiesError = message
            Haptics.notify(.error)
            throw error
        }
    }

    func loadZones() async throws -> [SWAEZone] {
        try await swae.fetchZones(account: utilityAccount)
    }

    func loadBuildings(zone: SWAEZone) async throws -> [SWAEBuilding] {
        try await swae.fetchBuildings(zoneId: zone.id, account: utilityAccount)
    }

    func loadFloors(building: SWAEBuilding) async throws -> [SWAEFloor] {
        try await swae.fetchFloors(buildId: building.id, account: utilityAccount)
    }

    func loadRooms(floor: SWAEFloor) async throws -> [SWAERoomOption] {
        try await swae.fetchRooms(floorId: floor.id, account: utilityAccount)
    }

    private func utilityMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: 登录

    func loginWithPassword(phone: String, password: String) async throws {
        let result = try await client.loginPassword(phone: phone, password: password, deviceId: store.deviceId)
        applyLogin(result, password: password)
    }

    func requestSMSCode(phone: String) async throws {
        guard isValidPhone(phone) else {
            throw WMXYError.server("请输入 11 位手机号")
        }
        try await client.sendSMSCode(phone: phone, deviceId: store.deviceId)
    }

    func loginWithSMS(phone: String, code: String) async throws {
        guard isValidPhone(phone) else {
            throw WMXYError.server("请输入 11 位手机号")
        }
        guard (4...8).contains(code.count) else {
            throw WMXYError.server("请输入有效的短信验证码")
        }
        let result = try await client.loginSMS(phone: phone, code: code, deviceId: store.deviceId)
        applyLogin(result, password: nil)
    }

    private func applyLogin(_ result: WMXYLoginResult, password: String?) {
        store.applyLogin(result)
        if store.rememberCredentials, let password, !password.isEmpty {
            CredentialVault.save(phone: result.phone, password: password)
        } else if !store.rememberCredentials {
            CredentialVault.clear()
        } else {
            CredentialVault.clear()
        }
        isSessionReady = true
        stopRelockCountdown()
        unlockCountdown = nil
        doorState = .locked
        selectedDeviceID = result.devices.first?.deviceId
        showLogin = false
        loginNotice = nil
        lastOperationText = nil
        Haptics.notify(.success)
        showToast("登录成功，已同步 \(result.devices.count) 把门锁", style: .success)
        scheduleUtilitiesRefresh()
    }

    func setDemoMode(_ enabled: Bool) {
        stopRelockCountdown()
        unlockCountdown = nil
        withAnimation(AppTheme.stateSpring) {
            doorState = .locked
        }
        store.setDemoMode(enabled)
        selectedDeviceID = store.devices.first?.deviceId
        lastOperationText = nil
        Haptics.impact(.light)
        showToast(enabled ? "已开启演示模式" : "已关闭演示模式", style: .info)
    }

    func signOut() {
        client.reset()
        isSessionReady = false
        stopRelockCountdown()
        unlockCountdown = nil
        doorState = .locked
        selectedDeviceID = nil
        store.signOut()
        utilityConfig = nil
        utilitiesError = nil
        lastOperationText = nil
        showToast("已退出登录", style: .info)
    }

    func openLogin(notice: String? = nil) {
        loginNotice = notice
        showLogin = true
    }

    private func prepareSession() async throws {
        guard store.isLoggedIn else { return }
        if isSessionReady { return }

        if let cached = store.sessionId, !cached.isEmpty {
            do {
                let result = try await client.resume(sessionId: cached, phone: store.phone ?? "")
                isSessionReady = true
                store.applyLogin(result)
                scheduleUtilitiesRefresh()
                return
            } catch {
                isSessionReady = false
            }
        }

        guard store.rememberCredentials, let credentials = CredentialVault.load() else {
            throw WMXYError.invalidSession
        }
        let result = try await client.loginPassword(
            phone: credentials.phone,
            password: credentials.password,
            deviceId: store.deviceId
        )
        isSessionReady = true
        store.applyLogin(result)
        scheduleUtilitiesRefresh()
    }

    // MARK: 辅助

    private func isValidPhone(_ phone: String) -> Bool {
        phone.count == 11 && phone.allSatisfy(\.isNumber) && phone.hasPrefix("1")
    }

    private func handleFailure(_ error: Error) {
        Haptics.notify(.error)
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastOperationText = "操作失败 · \(message)"
        showToast(message, style: .error)

        if case WMXYError.invalidSession = error {
            openLogin(notice: message)
        } else if case WMXYError.newDeviceVerification = error {
            openLogin(notice: message)
        }
    }

    func showToast(_ message: String, style: ToastMessage.Style, duration: Double = 2.8) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            toast = ToastMessage(message: message, style: style)
        }
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self?.toast = nil
            }
        }
    }

    // MARK: 生活服务文案

    func detail(for module: DormServiceModule) -> String {
        switch module.kind {
        case .utilities:
            if let detail = store.roomDetail, let meter = detail.primaryMeter {
                let kind = detail.kind(for: meter)
                return "今日 \(formatUtility(meter.todayUse)) \(kind.unit)"
            }
            if store.isDemoMode {
                return "约可用 \(store.estimatedElectricityDays) 天"
            }
            return "选择宿舍查询"
        case .history:
            return store.unlockThisWeekCount > 0
                ? "本周开锁 \(store.unlockThisWeekCount) 次"
                : "暂无记录"
        case .climate:
            return "未连接"
        case .campusCard:
            return "未接入"
        }
    }

    func value(for module: DormServiceModule) -> String {
        switch module.kind {
        case .utilities:
            if let detail = store.roomDetail, let meter = detail.primaryMeter {
                let kind = detail.kind(for: meter)
                return "\(formatUtility(meter.remaining)) \(kind.unit)"
            }
            if store.isDemoMode {
                return String(format: "%.1f kWh", store.electricityKWh)
            }
            return "—"
        case .history:
            return store.historyThisWeekCount > 0 ? "\(store.historyThisWeekCount) 条" : "0 条"
        case .climate:
            return "26°C"
        case .campusCard:
            return store.isDemoMode ? String(format: "¥%.1f", store.cardBalance) : "—"
        }
    }

    private func formatUtility(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        if value >= 100 {
            return String(format: "%.1f", value)
        }
        return value == value.rounded()
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
