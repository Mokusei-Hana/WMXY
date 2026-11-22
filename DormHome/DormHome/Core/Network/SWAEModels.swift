//
//  SWAEModels.swift
//  DormHome
//
//  完美校园「智能水电（SWAE）」数据模型与兼容解析器。
//
//  服务端在不同命令中会把同一个数值字段返回成 String / Double / Int，
//  例如 getbindroom 的 odd 为 "196.86"，而 h5_getstuindexpage 的 odd 为 232.7。
//  因此所有数值都经过 SWAEParsing 统一兼容解析，绝不依赖单一 JSON 类型。
//

import Foundation

// MARK: - 业务类型

enum SWAEBusinessType: Int, Codable, CaseIterable, Hashable {
    case electricity = 0
    case coldWater = 1
    case hotWater = 2

    init(raw: Int) {
        switch raw {
        case 0: self = .electricity
        case 1: self = .coldWater
        case 2: self = .hotWater
        default: self = .hotWater
        }
    }

    var title: String {
        switch self {
        case .electricity: return "电"
        case .coldWater: return "冷水"
        case .hotWater: return "热水"
        }
    }

    var unit: String {
        switch self {
        case .electricity: return "kWh"
        case .coldWater, .hotWater: return "t"
        }
    }

    var symbol: String {
        switch self {
        case .electricity: return "bolt.fill"
        case .coldWater, .hotWater: return "drop.fill"
        }
    }
}

/// 表计在 UI 上的分类。空调可能是 businesstype=0 的独立房间/表计，
/// 需要结合 devicename、roomfullname、accode 综合判断。
enum SWAEMeterKind: String, Hashable {
    case electricity
    case coldWater
    case hotWater
    case airConditioner
    case other

    var title: String {
        switch self {
        case .electricity: return "电表"
        case .coldWater: return "冷水表"
        case .hotWater: return "热水表"
        case .airConditioner: return "空调表"
        case .other: return "表计"
        }
    }

    var unit: String {
        switch self {
        case .electricity, .airConditioner: return "kWh"
        case .coldWater, .hotWater: return "t"
        case .other: return ""
        }
    }

    var symbol: String {
        switch self {
        case .electricity: return "bolt.fill"
        case .coldWater, .hotWater: return "drop.fill"
        case .airConditioner: return "air.conditioner.horizontal.fill"
        case .other: return "gauge.with.dots.needle.50percent"
        }
    }

    var statusOnText: String {
        switch self {
        case .electricity, .airConditioner: return "通电中"
        case .coldWater, .hotWater: return "供水正常"
        case .other: return "在线"
        }
    }

    var statusOffText: String {
        switch self {
        case .electricity, .airConditioner: return "已断电"
        case .coldWater, .hotWater: return "已关阀"
        case .other: return "离线"
        }
    }
}

// MARK: - 级联选择模型

struct SWAEZone: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
}

struct SWAEBuilding: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
}

struct SWAEFloor: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
}

struct SWAERoomOption: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
    /// 少数学校会在房间列表中直接返回 roomverify；优先使用服务端值。
    var roomverify: String?
}

// MARK: - 用量

struct SWAEDailyUsage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 服务端的 date 或 daydate，形如 "09-10"、"2026-09-10"。
    var dateText: String
    var weekday: String?
    var use: Double

    var shortDateText: String {
        let parts = dateText.split(separator: "-")
        guard parts.count >= 2 else { return dateText }
        return "\(parts[parts.count - 2])-\(parts[parts.count - 1])"
    }
}

struct SWAEMonthlyUsage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var yearMonth: String
    var use: Double
}

// MARK: - 表计

struct SWAEMeterDetail: Identifiable, Codable, Hashable {
    var deviceName: String
    var mac: String
    var businessType: Int
    var status: Int
    /// odd：剩余量。电=度，水=吨，不是金额。
    var remaining: Double
    /// 绑定房间 detaillist 的 use：已用量；详情页的今日用量单独放在 todayUse。
    var used: Double?
    var todayUse: Double
    var accode: String
    var sumBuy: Double?
    var sumSub: Double?
    var isShowPay: Bool
    var weekUseList: [SWAEDailyUsage]
    var monthUseList: [SWAEMonthlyUsage]

    var id: String {
        let key = mac.isEmpty ? "\(deviceName)-\(accode)" : mac
        return "\(key)-\(businessType)-\(deviceName)"
    }

    // 与服务端字段同名的便捷访问器，便于对照接口文档排查。
    var devicename: String { deviceName }
    var businesstype: Int { businessType }
    var odd: Double { remaining }
    var todayuse: Double { todayUse }
    var sumbuy: Double? { sumBuy }
    var sumsub: Double? { sumSub }
    var weekuselist: [SWAEDailyUsage] { weekUseList }
    var monthuselist: [SWAEMonthlyUsage] { monthUseList }

    var business: SWAEBusinessType { SWAEBusinessType(raw: businessType) }
    var isOn: Bool { status == 1 }
    var statusText: String { isOn ? kind.statusOnText : kind.statusOffText }

    var kind: SWAEMeterKind {
        if deviceName.contains("空调") { return .airConditioner }
        if accode.contains("51101") || accode.contains("51102") { return .electricity }
        if accode.contains("51201") || accode.contains("51202") { return .coldWater }
        switch businessType {
        case 0: return .electricity
        case 1: return .coldWater
        case 2: return .hotWater
        default: return .other
        }
    }

    var unit: String { kind.unit }

    var weeklyTotal: Double {
        weekUseList.reduce(0) { $0 + $1.use }
    }

    var dailyAverage: Double {
        guard !weekUseList.isEmpty else { return max(0, todayUse) }
        return weeklyTotal / Double(weekUseList.count)
    }

    /// 按近 7 日均值估算可用天数；没有历史用量时返回 nil，避免凭空预测。
    var estimatedDays: Int? {
        let average = dailyAverage
        guard average > 0.0001, remaining >= 0 else { return nil }
        return max(0, Int((remaining / average).rounded()))
    }
}

// MARK: - 房间

struct SWAERoomSummary: Identifiable, Codable, Hashable {
    var roomFullName: String
    var roomVerify: String
    var accountNum: String?
    var meterDetails: [SWAEMeterDetail]

    var id: String { roomVerify }

    // 与服务端字段同名的便捷访问器。
    var roomfullname: String { roomFullName }
    var roomverify: String { roomVerify }
    var detaillist: [SWAEMeterDetail] { meterDetails }

    var electricMeter: SWAEMeterDetail? {
        meterDetails.first { $0.businessType == 0 && !$0.deviceName.contains("空调") }
            ?? meterDetails.first { $0.businessType == 0 }
    }

    var primaryMeter: SWAEMeterDetail? {
        electricMeter ?? meterDetails.first
    }
}

struct SWAERoomDetail: Identifiable, Codable, Hashable {
    var roomFullName: String
    var roomVerify: String
    var roomNum: String?
    var meters: [SWAEMeterDetail]
    var updatedAt: Date
    var hasSubsidy: Bool

    var id: String { roomVerify }

    // 与服务端字段同名的便捷访问器。
    var roomfullname: String { roomFullName }
    var roomverify: String { roomVerify }
    var modlist: [SWAEMeterDetail] { meters }

    var electricMeter: SWAEMeterDetail? {
        meters.first { $0.kind == .electricity }
            ?? meters.first { $0.businessType == 0 && !$0.deviceName.contains("空调") }
    }

    var airConditionerMeter: SWAEMeterDetail? {
        meters.first { $0.kind == .airConditioner }
    }

    var coldWaterMeter: SWAEMeterDetail? {
        meters.first { $0.kind == .coldWater }
    }

    var hotWaterMeter: SWAEMeterDetail? {
        meters.first { $0.kind == .hotWater }
    }

    var primaryMeter: SWAEMeterDetail? {
        electricMeter ?? meters.first
    }

    func kind(for meter: SWAEMeterDetail) -> SWAEMeterKind {
        if meter.kind == .airConditioner { return .airConditioner }
        if roomFullName.contains("空调"), meter.businessType == 0 { return .airConditioner }
        return meter.kind
    }
}

// MARK: - 配置

struct SWAEConfig: Codable, Hashable {
    var systemName: String
    var electricPriceHint: String
    var coldWaterPriceHint: String
    var hotWaterPriceHint: String
    var payEnabled: Bool
    var hasSubsidy: Bool

    var electricityUnitPrice: Double? {
        Self.price(in: electricPriceHint)
    }

    var coldWaterUnitPrice: Double? {
        Self.price(in: coldWaterPriceHint)
    }

    var hotWaterUnitPrice: Double? {
        Self.price(in: hotWaterPriceHint)
    }

    static let fallback = SWAEConfig(
        systemName: "物联网水电管理系统",
        electricPriceHint: "电费收费标准为0.65元/度",
        coldWaterPriceHint: "冷水费收费标准为1.5元/吨",
        hotWaterPriceHint: "热水费收费标准为2.5元/吨",
        payEnabled: true,
        hasSubsidy: false
    )

    private static func price(in text: String) -> Double? {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*元\\s*[/／]?\\s*(度|吨)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }
}

// MARK: - 兼容解析器

enum SWAEParsing {

    // MARK: 基础类型

    static func string(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String {
            let cleaned = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
            if let parsed = Double(cleaned) { return parsed }
            let pattern = "[-+]?[0-9]*\\.?[0-9]+"
            if let range = cleaned.range(of: pattern, options: .regularExpression),
               let parsed = Double(cleaned[range]) {
                return parsed
            }
        }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        guard let double = double(value) else { return nil }
        return Int(double.rounded())
    }

    static func bool(_ value: Any?) -> Bool? {
        guard let value else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            let normalized = string.lowercased()
            if ["1", "true", "yes", "on"].contains(normalized) { return true }
            if ["0", "false", "no", "off"].contains(normalized) { return false }
        }
        return nil
    }

    // MARK: 级联实体

    static func entities(from inner: [String: Any]) -> [(id: Int, name: String)] {
        let list = inner.arrayValue("data")
            ?? inner.arrayValue("list")
            ?? inner.arrayValue("zonelist")
            ?? []
        return list.compactMap { item in
            guard let id = int(item["id"]), let name = string(item["name"]), !name.isEmpty else {
                return nil
            }
            return (id, name)
        }
    }

    static func zones(from inner: [String: Any]) -> [SWAEZone] {
        entities(from: inner).map { SWAEZone(id: $0.id, name: $0.name) }
    }

    static func buildings(from inner: [String: Any]) -> [SWAEBuilding] {
        entities(from: inner).map { SWAEBuilding(id: $0.id, name: $0.name) }
    }

    static func floors(from inner: [String: Any]) -> [SWAEFloor] {
        entities(from: inner).map { SWAEFloor(id: $0.id, name: $0.name) }
    }

    static func rooms(from inner: [String: Any]) -> [SWAERoomOption] {
        let list = inner.arrayValue("data")
            ?? inner.arrayValue("list")
            ?? inner.arrayValue("roomnumlist")
            ?? []
        return list.compactMap { item in
            guard let id = int(item["id"]), let name = string(item["name"]), !name.isEmpty else {
                return nil
            }
            let verify = string(item["roomverify"]).flatMap { $0.isEmpty ? nil : $0 }
            return SWAERoomOption(id: id, name: name, roomverify: verify)
        }
    }

    // MARK: 绑定房间

    static func boundRooms(from inner: [String: Any]) -> [SWAERoomSummary] {
        let flag = string(inner["existflag"]) ?? "0"

        if let list = inner.arrayValue("roomlist"), !list.isEmpty {
            return list.compactMap { room(from: $0) }
        }
        if flag == "1" {
            return [room(from: inner)].compactMap { $0 }
        }
        return []
    }

    static func room(from raw: [String: Any]) -> SWAERoomSummary? {
        guard let verify = string(raw["roomverify"]), !verify.isEmpty else { return nil }
        let name = string(raw["roomfullname"]).flatMap { $0.isEmpty ? nil : $0 } ?? verify
        let meters = (raw.arrayValue("detaillist") ?? []).compactMap { meter(from: $0) }
        return SWAERoomSummary(
            roomFullName: name,
            roomVerify: verify,
            accountNum: string(raw["account_num"]).flatMap { $0.isEmpty ? nil : $0 },
            meterDetails: meters
        )
    }

    // MARK: 表计

    static func meter(from raw: [String: Any]) -> SWAEMeterDetail? {
        let businessType = int(raw["businesstype"]) ?? int(raw["businessType"]) ?? 0
        let deviceName = string(raw["devicename"])
            ?? string(raw["deviceName"])
            ?? defaultDeviceName(for: businessType)
        let mac = string(raw["mac"]) ?? ""
        let accode = string(raw["accode"]) ?? string(raw["ecardacccode"]) ?? ""
        let remaining = double(raw["odd"]) ?? double(raw["remaining"]) ?? 0
        let status = int(raw["status"]) ?? 1

        let weekSource = raw.arrayValue("weekuselist")
            ?? raw.arrayValue("weekUseList")
            ?? raw.arrayValue("dayuselist")
            ?? []
        let weeks = weekSource.compactMap { dailyUsage(from: $0) }

        let monthSource = raw.arrayValue("monthuselist")
            ?? raw.arrayValue("monthUseList")
            ?? []
        let months = monthSource.compactMap { monthlyUsage(from: $0) }

        guard raw["devicename"] != nil
                || raw["deviceName"] != nil
                || raw["odd"] != nil
                || raw["mac"] != nil
                || !weeks.isEmpty else {
            return nil
        }

        return SWAEMeterDetail(
            deviceName: deviceName,
            mac: mac,
            businessType: businessType,
            status: status,
            remaining: remaining,
            used: double(raw["use"]),
            todayUse: double(raw["todayuse"]) ?? double(raw["todayUse"]) ?? 0,
            accode: accode,
            sumBuy: double(raw["sumbuy"]) ?? double(raw["sumBuy"]),
            sumSub: double(raw["sumsub"]) ?? double(raw["sumSub"]),
            isShowPay: bool(raw["isshowpay"]) ?? bool(raw["isShowPay"]) ?? false,
            weekUseList: weeks,
            monthUseList: months
        )
    }

    static func dailyUsage(from raw: [String: Any]) -> SWAEDailyUsage? {
        let dateText = string(raw["date"])
            ?? string(raw["daydate"])
            ?? string(raw["dayDate"])
            ?? ""
        let use = double(raw["use"]) ?? double(raw["dayuse"]) ?? double(raw["dayUse"]) ?? 0
        guard !dateText.isEmpty || use > 0 else { return nil }
        return SWAEDailyUsage(
            dateText: dateText,
            weekday: string(raw["weekday"]),
            use: use
        )
    }

    static func monthlyUsage(from raw: [String: Any]) -> SWAEMonthlyUsage? {
        let yearMonth = string(raw["yearmonth"])
            ?? string(raw["yearMonth"])
            ?? string(raw["month"])
            ?? ""
        let use = double(raw["monthuse"]) ?? double(raw["monthUse"]) ?? 0
        guard !yearMonth.isEmpty || use > 0 else { return nil }
        return SWAEMonthlyUsage(yearMonth: yearMonth, use: use)
    }

    // MARK: 房间详情

    static func detail(
        from inner: [String: Any],
        requestedVerify: String? = nil,
        fetchedAt: Date = Date()
    ) -> SWAERoomDetail? {
        let verify = string(inner["roomverify"]).flatMap { $0.isEmpty ? nil : $0 }
            ?? requestedVerify
            ?? ""
        let list = inner.arrayValue("modlist")
            ?? inner.arrayValue("modList")
            ?? []
        let meters = list.compactMap { meter(from: $0) }
        guard !meters.isEmpty || !verify.isEmpty else { return nil }

        let name = string(inner["roomfullname"]).flatMap { $0.isEmpty ? nil : $0 } ?? verify
        return SWAERoomDetail(
            roomFullName: name,
            roomVerify: verify,
            roomNum: string(inner["roomnum"]).flatMap { $0.isEmpty ? nil : $0 },
            meters: meters,
            updatedAt: fetchedAt,
            hasSubsidy: bool(inner["isshowsubsidy"]) ?? false
        )
    }

    // MARK: 配置

    static func config(from inner: [String: Any]) -> SWAEConfig {
        let data = inner.dictionaryValue("data") ?? inner
        let systemName = string(data["system_name"]).flatMap { $0.isEmpty ? nil : $0 }
            ?? "物联网水电管理系统"
        let electric = stripHTML(string(data["h5_fixed_d_remind"]) ?? "")
        let cold = stripHTML(string(data["h5_fixed_colds_remind"]) ?? "")
        let hot = stripHTML(string(data["h5_fixed_hots_remind"]) ?? "")

        return SWAEConfig(
            systemName: systemName,
            electricPriceHint: electric.isEmpty ? SWAEConfig.fallback.electricPriceHint : electric,
            coldWaterPriceHint: cold.isEmpty ? SWAEConfig.fallback.coldWaterPriceHint : cold,
            hotWaterPriceHint: hot.isEmpty ? SWAEConfig.fallback.hotWaterPriceHint : hot,
            payEnabled: bool(data["h5_pay_switch"]) ?? true,
            hasSubsidy: bool(data["subOrNot"]) ?? bool(inner["isshowsubsidy"]) ?? false
        )
    }

    static func stripHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'"
        ]
        for (key, value) in entities {
            text = text.replacingOccurrences(of: key, with: value)
        }
        return text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: 辅助

    static func defaultDeviceName(for businessType: Int) -> String {
        switch businessType {
        case 0: return "电控"
        case 1: return "冷水表"
        case 2: return "热水表"
        default: return "表计"
        }
    }
}

// MARK: - 房间名匹配

enum UtilityRoomName {
    /// 用房间名匹配已绑定房间，优先复用服务端生成的 roomverify。
    static func matches(bound: String, selected: String) -> Bool {
        guard !bound.isEmpty, !selected.isEmpty else { return false }
        if bound == selected || bound.contains(selected) { return true }
        let cleaned = selected
            .replacingOccurrences(of: "房间", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        return bound == cleaned
            || bound.hasSuffix("_\(cleaned)")
            || bound.hasSuffix("-\(cleaned)")
            || bound.hasSuffix(" \(cleaned)")
    }
}

/// 级联接口只返回房间 id/name，roomverify 通常由服务端生成。
/// 对于未绑定房间，按 2502 的已知格式依次探测只读详情接口；
/// 任一格式成功即采用服务端返回的 roomverify，写操作完全不参与。
enum SWAERoomVerify {
    static func candidates(
        zoneID: Int,
        buildID: Int,
        floorID: Int,
        room: SWAERoomOption,
        preferredVerify: String? = nil
    ) -> [String] {
        var values: [String] = []
        if let preferredVerify, !preferredVerify.isEmpty {
            values.append(preferredVerify)
        }
        if let verify = room.roomverify, !verify.isEmpty {
            values.append(verify)
        }

        let cleanedName = room.name
            .replacingOccurrences(of: "房间", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let roomKeys = [cleanedName, String(room.id)]
            .filter { !$0.isEmpty }

        for key in roomKeys {
            values.append("\(zoneID)-\(buildID)--\(floorID)-\(key)")
            values.append("\(zoneID)-\(buildID)-\(floorID)-\(key)")
        }

        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
