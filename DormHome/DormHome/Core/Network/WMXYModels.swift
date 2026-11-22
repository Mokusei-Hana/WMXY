//
//  WMXYModels.swift
//  DormHome
//
//  完美校园接口与本地业务的数据模型。
//

import Foundation
import SwiftUI

// MARK: - 错误

enum WMXYError: LocalizedError, Equatable {
    case crypto(String)
    case network(String)
    case invalidResponse(String)
    case server(String)
    case newDeviceVerification
    case invalidSession
    case missingParams
    case loginRequired

    var errorDescription: String? {
        switch self {
        case .crypto(let message):
            return message
        case .network(let message):
            return "网络连接失败：\(message)"
        case .invalidResponse(let message):
            return "服务返回异常：\(message)"
        case .server(let message):
            return message.isEmpty ? "服务暂时不可用，请稍后再试" : message
        case .newDeviceVerification:
            return "检测到新设备登录，请使用短信验证码验证"
        case .invalidSession:
            return "登录已过期，请重新登录"
        case .missingParams:
            return "登录授权失败，请重试"
        case .loginRequired:
            return "请先登录完美校园账号"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .newDeviceVerification:
            return "请切换到「短信验证码」完成一次验证。"
        case .invalidSession:
            return "重新登录后会自动同步你的门锁。"
        default:
            return nil
        }
    }
}

// MARK: - 门锁

struct DoorDevice: Identifiable, Codable, Hashable {
    var deviceId: String
    var serialNo: String
    var name: String
    var typeName: String
    var battery: Int?
    var isOnline: Bool
    var supportMode: String?
    var roomName: String?

    var id: String { deviceId }

    var batterySymbol: String {
        guard let battery else { return "battery.0percent" }
        switch battery {
        case 88...: return "battery.100percent"
        case 63...: return "battery.75percent"
        case 38...: return "battery.50percent"
        case 13...: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    static let demo = DoorDevice(
        deviceId: "demo-412",
        serialNo: "SN-DEMO-0412",
        name: "3栋 412 宿舍门锁",
        typeName: "智能宿舍门锁",
        battery: 86,
        isOnline: true,
        supportMode: "1,2,4",
        roomName: "3栋 412"
    )

    static func parse(_ raw: [String: Any]) -> DoorDevice? {
        guard let deviceId = raw.stringValue("deviceId"), !deviceId.isEmpty else { return nil }
        let sn = raw.stringValue("sn") ?? raw.stringValue("serialNo") ?? ""
        let name = raw.stringValue("deviceName")
            ?? raw.stringValue("name")
            ?? "宿舍门锁"
        let typeName = raw.stringValue("deviceTypeName")
            ?? raw.stringValue("deviceType")
            ?? "智能门锁"

        var battery: Int?
        if let value = raw["battery"] as? Int {
            battery = value
        } else if let text = raw.stringValue("battery") {
            let digits = text.filter(\.isNumber)
            battery = Int(digits)
        }

        let online = raw.boolValue("onlineStatus")
            ?? raw.boolValue("online")
            ?? true

        return DoorDevice(
            deviceId: deviceId,
            serialNo: sn,
            name: name,
            typeName: typeName,
            battery: battery,
            isOnline: online,
            supportMode: raw.stringValue("supportMode"),
            roomName: raw.stringValue("roomName") ?? raw.stringValue("room")
        )
    }
}

// MARK: - 记录

enum DoorAction: String, Codable, CaseIterable, Hashable {
    case unlock
    case lock

    var title: String { self == .unlock ? "开锁" : "上锁" }
    var symbol: String { self == .unlock ? "lock.open.fill" : "lock.fill" }
}

enum UnlockChannel: String, Codable, CaseIterable, Hashable {
    case remote
    case autoRelock
    case demo
    case local

    var title: String {
        switch self {
        case .remote: return "远程开锁"
        case .autoRelock: return "自动上锁"
        case .demo: return "演示"
        case .local: return "手动上锁"
        }
    }
}

struct UnlockRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var deviceID: String
    var deviceName: String
    var action: DoorAction
    var channel: UnlockChannel
    var success: Bool
    var detail: String
    var isDemo: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        deviceID: String,
        deviceName: String,
        action: DoorAction,
        channel: UnlockChannel,
        success: Bool = true,
        detail: String,
        isDemo: Bool = false
    ) {
        self.id = id
        self.date = date
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.action = action
        self.channel = channel
        self.success = success
        self.detail = detail
        self.isDemo = isDemo
    }
}

// MARK: - 水电数据

struct ElectricityUsagePoint: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var kwh: Double

    init(id: UUID = UUID(), date: Date, kwh: Double) {
        self.id = id
        self.date = date
        self.kwh = kwh
    }
}

// MARK: - 登录结果

struct WMXYLoginResult {
    var sessionId: String
    var outid: String
    var userName: String?
    var phone: String
    var devices: [DoorDevice]
    var loginDate: Date
}

// MARK: - JSON 辅助

extension Dictionary where Key == String, Value == Any {
    func stringValue(_ key: String) -> String? {
        guard let value = self[key] else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    func intValue(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    func boolValue(_ key: String) -> Bool? {
        guard let value = self[key] else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            let normalized = string.lowercased()
            if ["1", "true", "yes", "online", "在线"].contains(normalized) { return true }
            if ["0", "false", "no", "offline", "离线"].contains(normalized) { return false }
        }
        return nil
    }

    func dictionaryValue(_ key: String) -> [String: Any]? {
        self[key] as? [String: Any]
    }

    func arrayValue(_ key: String) -> [[String: Any]]? {
        if let array = self[key] as? [[String: Any]] { return array }
        if let array = self[key] as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        return nil
    }
}
