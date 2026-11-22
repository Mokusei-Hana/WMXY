//
//  DormServiceModule.swift
//  DormHome
//
//  驱动首页 Bento 网格与设置页模块开关的模块注册表。
//

import SwiftUI

struct DormServiceModule: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable {
        case utilities
        case history
        case climate
        case campusCard
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let badge: String?

    var id: String { kind.rawValue }

    static func == (lhs: DormServiceModule, rhs: DormServiceModule) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum ModuleRegistry {

    static let all: [DormServiceModule] = [
        DormServiceModule(
            kind: .utilities,
            title: "水电费",
            subtitle: "电量余量与用水余额",
            symbol: "bolt.fill",
            tint: AppTheme.electricYellow,
            badge: nil
        ),
        DormServiceModule(
            kind: .history,
            title: "开门记录",
            subtitle: "每一次开锁与回锁",
            symbol: "clock.arrow.circlepath",
            tint: AppTheme.historyGreen,
            badge: nil
        ),
        DormServiceModule(
            kind: .climate,
            title: "空调控温",
            subtitle: "回寝前提前降温",
            symbol: "air.conditioner.horizontal.fill",
            tint: AppTheme.climateBlue,
            badge: "即将接入"
        ),
        DormServiceModule(
            kind: .campusCard,
            title: "校园一卡通",
            subtitle: "余额与消费流水",
            symbol: "creditcard.fill",
            tint: AppTheme.campusPurple,
            badge: "即将接入"
        )
    ]

    static let defaultEnabledIDs = all.map(\.id)

    static func enabled(ids: [String]) -> [DormServiceModule] {
        all.filter { ids.contains($0.id) }
    }

    static func module(for kind: DormServiceModule.Kind) -> DormServiceModule {
        all.first(where: { $0.kind == kind }) ?? all[0]
    }
}
