//
//  DormStore.swift
//  DormHome
//
//  本地持久化：固定设备 ID、登录态、门锁缓存、开门历史、外观与模块偏好。
//  密码仅写入 Keychain（Security），绝不进入 UserDefaults。
//

import Foundation
import Security
import SwiftUI

// MARK: - Keychain 凭证

enum CredentialVault {
    struct Credentials: Codable {
        var phone: String
        var password: String
    }

    private static let service = "com.sakiyui.dormhome.credentials"
    private static let account = "wanxiao"

    static func save(phone: String, password: String) {
        guard let data = try? JSONEncoder().encode(Credentials(phone: phone, password: password)) else { return }
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 持久化状态

struct PersistedState: Codable {
    var schemaVersion: Int
    var deviceId: String
    var sessionId: String?
    var sessionTimestamp: Date?
    var outid: String?
    var userName: String?
    var phone: String?
    var isLoggedIn: Bool
    var devices: [DoorDevice]
    var history: [UnlockRecord]
    var themeMode: ThemeMode
    var enabledModuleIDs: [String]
    var autoRelockSeconds: Int
    var rememberCredentials: Bool
    var electricityKWh: Double
    var waterBalance: Double
    var cardBalance: Double
    var electricityUsage: [ElectricityUsagePoint]
    var hasSeededDemoHistory: Bool

    // SWAE 水电缓存（可选字段，兼容旧版本持久化数据）
    var boundRooms: [SWAERoomSummary]?
    var selectedRoomVerify: String?
    var selectedRoomName: String?
    var roomDetail: SWAERoomDetail?
    var lastUtilitySyncDate: Date?
    var demoModeEnabled: Bool?

    static func fresh() -> PersistedState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let samples: [Double] = [3.1, 2.6, 4.2, 3.0, 2.2, 3.7, 2.4]
        let usage = samples.enumerated().map { index, value in
            ElectricityUsagePoint(
                date: calendar.date(byAdding: .day, value: index - 6, to: today) ?? today,
                kwh: value
            )
        }

        return PersistedState(
            schemaVersion: 2,
            deviceId: "wx-door-\(Int(Date().timeIntervalSince1970))",
            sessionId: nil,
            sessionTimestamp: nil,
            outid: nil,
            userName: nil,
            phone: nil,
            isLoggedIn: false,
            devices: [],
            history: [],
            themeMode: .system,
            enabledModuleIDs: ModuleRegistry.defaultEnabledIDs,
            autoRelockSeconds: 30,
            rememberCredentials: true,
            electricityKWh: 42.6,
            waterBalance: 18.3,
            cardBalance: 128.5,
            electricityUsage: usage,
            hasSeededDemoHistory: false,
            boundRooms: [],
            selectedRoomVerify: nil,
            selectedRoomName: nil,
            roomDetail: nil,
            lastUtilitySyncDate: nil,
            demoModeEnabled: false
        )
    }
}

// MARK: - Store

@MainActor
final class DormStore: ObservableObject {

    @Published private(set) var state: PersistedState

    private let defaults: UserDefaults
    private let stateKey = "dormhome.state.v1"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.encoder = encoder
        self.decoder = decoder

        if let data = defaults.data(forKey: stateKey),
           let decoded = try? decoder.decode(PersistedState.self, from: data) {
            self.state = decoded
        } else {
            self.state = PersistedState.fresh()
        }

        if state.deviceId.isEmpty {
            state.deviceId = "wx-door-\(Int(Date().timeIntervalSince1970))"
        }
        if state.autoRelockSeconds < 10 {
            state.autoRelockSeconds = 30
        }
        if state.isLoggedIn || !(state.demoModeEnabled ?? false) {
            state.history.removeAll { $0.isDemo }
        }
        persistence()
    }

    // MARK: 账户与门锁

    var deviceId: String { state.deviceId }
    var isLoggedIn: Bool { state.isLoggedIn }
    var isDemoMode: Bool { !state.isLoggedIn && (state.demoModeEnabled ?? false) }
    var userName: String? { state.userName }
    var phone: String? { state.phone }
    var outid: String? { state.outid }
    var sessionId: String? { state.sessionId }
    var sessionTimestamp: Date? { state.sessionTimestamp }
    var rememberCredentials: Bool { state.rememberCredentials }

    /// 真实账号使用已授权门锁；演示模式提供 1 把模拟门锁；未登录且非演示模式为空。
    var devices: [DoorDevice] {
        if isLoggedIn { return state.devices }
        if isDemoMode { return [DoorDevice.demo] }
        return []
    }

    var roomName: String {
        if let first = devices.first {
            if let room = first.roomName, !room.isEmpty { return room }
            let prefix = first.name.components(separatedBy: " ").dropLast().joined(separator: " ")
            if !prefix.isEmpty { return prefix }
            return first.name
        }
        if let selected = state.selectedRoomName, !selected.isEmpty {
            return selected
        }
        return isDemoMode ? "3栋 412" : "我的宿舍"
    }

    var sessionShortID: String {
        guard let sessionId, !sessionId.isEmpty else { return "—" }
        return String(sessionId.prefix(10)) + "…"
    }

    var sessionAgeText: String {
        guard let timestamp = state.sessionTimestamp else { return "未登录" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var sessionStatusText: String {
        if isLoggedIn { return "已连接" }
        if isDemoMode { return "演示模式" }
        return "未登录"
    }

    var history: [UnlockRecord] {
        let filtered = isDemoMode ? state.history : state.history.filter { !$0.isDemo }
        return filtered.sorted { $0.date > $1.date }
    }

    var historyThisWeekCount: Int {
        guard let week = weekCalendar.dateInterval(of: .weekOfYear, for: Date()) else { return history.count }
        return history.filter { week.contains($0.date) }.count
    }

    var unlockThisWeekCount: Int {
        guard let week = weekCalendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return history.filter { week.contains($0.date) && $0.action == .unlock }.count
    }

    private var weekCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        return calendar
    }

    var lastUnlock: UnlockRecord? {
        history.first(where: { $0.action == .unlock })
    }

    var lastActivityText: String {
        guard let record = history.first else { return "还没有操作记录" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "\(formatter.string(from: record.date)) · \(record.detail)"
    }

    // MARK: 外观与模块

    var themeMode: ThemeMode { state.themeMode }

    func setThemeMode(_ mode: ThemeMode) {
        state.themeMode = mode
        persistence()
    }

    var enabledModuleIDs: [String] { state.enabledModuleIDs }

    func isModuleEnabled(_ id: String) -> Bool {
        state.enabledModuleIDs.contains(id)
    }

    func setModule(_ id: String, enabled: Bool) {
        var ids = Set(state.enabledModuleIDs)
        if enabled { ids.insert(id) } else { ids.remove(id) }
        state.enabledModuleIDs = ModuleRegistry.all.map(\.id).filter { ids.contains($0) }
        persistence()
    }

    var autoRelockSeconds: Int { state.autoRelockSeconds }

    func setAutoRelockSeconds(_ seconds: Int) {
        state.autoRelockSeconds = min(60, max(10, seconds))
        persistence()
    }

    // MARK: 水电 / 一卡通

    var electricityKWh: Double { state.electricityKWh }
    var waterBalance: Double { state.waterBalance }
    var cardBalance: Double { state.cardBalance }
    var electricityUsage: [ElectricityUsagePoint] { state.electricityUsage }

    var averageElectricity: Double {
        guard !state.electricityUsage.isEmpty else { return 0 }
        return state.electricityUsage.reduce(0) { $0 + $1.kwh } / Double(state.electricityUsage.count)
    }

    var estimatedElectricityDays: Int {
        let average = averageElectricity
        guard average > 0 else { return 0 }
        return Int((state.electricityKWh / average).rounded())
    }

    // MARK: SWAE 实时水电

    var boundRooms: [SWAERoomSummary] { state.boundRooms ?? [] }

    var selectedRoomVerify: String? { state.selectedRoomVerify }
    var selectedRoomName: String? { state.selectedRoomName }
    var roomDetail: SWAERoomDetail? { state.roomDetail }
    var lastUtilitySyncDate: Date? { state.lastUtilitySyncDate }
    var hasLiveUtilities: Bool { state.roomDetail != nil }

    var selectedRoomSummary: SWAERoomSummary? {
        guard let verify = state.selectedRoomVerify else { return nil }
        return boundRooms.first { $0.roomVerify == verify }
    }

    var utilityRoomName: String {
        state.selectedRoomName
            ?? state.roomDetail?.roomFullName
            ?? (isDemoMode ? "3栋 412" : "未选择宿舍")
    }

    var lastUtilitySyncText: String {
        guard let date = state.lastUtilitySyncDate else { return "暂未更新" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M月d日 HH:mm"
        return "更新于 \(formatter.string(from: date))"
    }

    /// 缓存 getbindroom 结果；保留用户手动选择的房间，不被自动绑定列表覆盖。
    func applyBoundRooms(_ rooms: [SWAERoomSummary]) {
        var merged = rooms
        if let verify = state.selectedRoomVerify,
           !merged.contains(where: { $0.roomVerify == verify }),
           let name = state.selectedRoomName,
           !name.isEmpty {
            let meters = state.roomDetail?.roomVerify == verify
                ? (state.roomDetail?.meters ?? [])
                : []
            merged.append(
                SWAERoomSummary(
                    roomFullName: name,
                    roomVerify: verify,
                    accountNum: nil,
                    meterDetails: meters
                )
            )
        }
        state.boundRooms = merged
        if state.selectedRoomVerify == nil, let first = rooms.first {
            state.selectedRoomVerify = first.roomVerify
            state.selectedRoomName = first.roomFullName
        }
        if rooms.isEmpty, state.selectedRoomVerify == nil {
            state.roomDetail = nil
        }
        persistence()
    }

    func selectUtilityRoom(_ room: SWAERoomSummary) {
        state.selectedRoomVerify = room.roomVerify
        state.selectedRoomName = room.roomFullName
        state.roomDetail = nil
        state.boundRooms = state.boundRooms?.isEmpty == false ? state.boundRooms : [room]
        if let rooms = state.boundRooms, !rooms.contains(where: { $0.roomVerify == room.roomVerify }) {
            state.boundRooms = rooms + [room]
        }
        persistence()
    }

    func selectUtilityRoom(roomVerify: String, name: String) {
        state.selectedRoomVerify = roomVerify
        state.selectedRoomName = name
        state.roomDetail = nil
        persistence()
    }

    func applyRoomDetail(_ detail: SWAERoomDetail) {
        state.roomDetail = detail
        if !detail.roomVerify.isEmpty {
            state.selectedRoomVerify = detail.roomVerify
        }
        if !detail.roomFullName.isEmpty {
            state.selectedRoomName = detail.roomFullName
        }
        state.lastUtilitySyncDate = detail.updatedAt
        persistence()
    }

    func markUtilitySynced(at date: Date = Date()) {
        state.lastUtilitySyncDate = date
        persistence()
    }

    func clearUtilityData() {
        state.boundRooms = []
        state.selectedRoomVerify = nil
        state.selectedRoomName = nil
        state.roomDetail = nil
        state.lastUtilitySyncDate = nil
        persistence()
    }

    // MARK: 登录状态

    func applyLogin(_ result: WMXYLoginResult) {
        state.sessionId = result.sessionId
        state.sessionTimestamp = result.loginDate
        state.outid = result.outid
        state.userName = result.userName
        state.phone = result.phone
        state.isLoggedIn = true
        state.demoModeEnabled = false
        state.devices = result.devices
        state.history.removeAll { $0.isDemo }
        persistence()
    }

    func setDemoMode(_ enabled: Bool) {
        guard !state.isLoggedIn else {
            state.demoModeEnabled = false
            state.history.removeAll { $0.isDemo }
            persistence()
            return
        }
        state.demoModeEnabled = enabled
        if !enabled {
            state.history.removeAll { $0.isDemo }
        }
        persistence()
    }

    func clearDemoHistory() {
        state.history.removeAll { $0.isDemo }
        persistence()
    }

    func updateDevices(_ devices: [DoorDevice]) {
        guard isLoggedIn else { return }
        state.devices = devices
        persistence()
    }

    func setRememberCredentials(_ enabled: Bool) {
        state.rememberCredentials = enabled
        if !enabled {
            CredentialVault.clear()
        }
        persistence()
    }

    func signOut() {
        state.isLoggedIn = false
        state.demoModeEnabled = false
        state.sessionId = nil
        state.sessionTimestamp = nil
        state.outid = nil
        state.userName = nil
        state.phone = nil
        state.devices = []
        state.boundRooms = []
        state.selectedRoomVerify = nil
        state.selectedRoomName = nil
        state.roomDetail = nil
        state.lastUtilitySyncDate = nil
        state.history.removeAll { $0.isDemo }
        CredentialVault.clear()
        persistence()
    }

    // MARK: 历史记录

    func record(_ record: UnlockRecord) {
        state.history.insert(record, at: 0)
        if state.history.count > 120 {
            state.history = Array(state.history.prefix(120))
        }
        persistence()
    }

    func clearHistory() {
        state.history.removeAll()
        persistence()
    }

    func deleteHistory(_ record: UnlockRecord) {
        state.history.removeAll { $0.id == record.id }
        persistence()
    }

    // MARK: 持久化

    private func persistence() {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }
}
