//
//  AppTheme.swift
//  DormHome
//
//  iOS 26 Liquid Glass 视觉系统。
//  色板、圆角、间距与字号严格对应 DESIGN_SPEC.md。
//

import SwiftUI

// MARK: - 门锁视觉状态

enum DoorVisualState: String, CaseIterable, Hashable {
    case locked
    case unlocking
    case unlocked

    var title: String {
        switch self {
        case .locked: return "已上锁"
        case .unlocking: return "正在开锁"
        case .unlocked: return "已开锁"
        }
    }
}

// MARK: - 外观模式

enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - 主题

enum AppTheme {

    // 空间节奏
    static let screenPadding: CGFloat = 20
    static let moduleSpacing: CGFloat = 20
    static let tileSpacing: CGFloat = 14
    static let heroCorner: CGFloat = 34
    static let tileCorner: CGFloat = 24

    // MARK: 语义强调色

    static let actionBlue = Color(light: 0x007AFF, dark: 0x0A84FF)
    static let actionCyan = Color(light: 0x34AADC, dark: 0x5AC8FA)
    static let onlineGreen = Color(light: 0x28CD41, dark: 0x30D158)
    static let warningAmber = Color(light: 0xFF9500, dark: 0xFF9F0A)
    static let dangerRed = Color(light: 0xFF3B30, dark: 0xFF453A)

    static let electricYellow = Color(light: 0xF5A623, dark: 0xFFD60A)
    static let waterBlue = Color(light: 0x0A84FF, dark: 0x64D2FF)
    static let climateBlue = Color(light: 0x007AFF, dark: 0x64D2FF)
    static let campusPurple = Color(light: 0xAF52DE, dark: 0xBF5AF2)
    static let historyGreen = Color(light: 0x34C759, dark: 0x30D158)

    static let accent = Color(light: 0x007AFF, dark: 0x0A84FF)

    // MARK: 状态色

    static func accent(for state: DoorVisualState) -> Color {
        switch state {
        case .locked: return actionBlue
        case .unlocking: return warningAmber
        case .unlocked: return onlineGreen
        }
    }

    static func accentGradient(for state: DoorVisualState) -> LinearGradient {
        let colors: [Color]
        switch state {
        case .locked:
            colors = [actionCyan, actionBlue]
        case .unlocking:
            colors = [Color(hex: 0xFFD60A), warningAmber]
        case .unlocked:
            colors = [Color(hex: 0x6EE7A8), onlineGreen]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: MeshGradient 色板（DESIGN_SPEC §2.1）

    static func meshColors(for state: DoorVisualState, scheme: ColorScheme) -> [Color] {
        let hexes: [Int]
        if scheme == .dark {
            switch state {
            case .locked:
                hexes = [0x070B14, 0x0C1426, 0x09111F,
                         0x10203A, 0x162C4E, 0x0F1D36,
                         0x080D18, 0x0B1322, 0x060911]
            case .unlocking:
                hexes = [0x081422, 0x0E2A42, 0x0A1A2E,
                         0x103B56, 0x1A4F6E, 0x12344D,
                         0x07111D, 0x0B1C2D, 0x060D16]
            case .unlocked:
                hexes = [0x061612, 0x0A2920, 0x071C17,
                         0x0E3B2D, 0x144D3B, 0x0C3025,
                         0x05120E, 0x081D16, 0x040D0B]
            }
        } else {
            switch state {
            case .locked:
                hexes = [0xEEF4FC, 0xE4EFFC, 0xF2F6FC,
                         0xDCEBFA, 0xEAF3FD, 0xE3EEFA,
                         0xF5F7FA, 0xF2F5F9, 0xF7F9FC]
            case .unlocking:
                hexes = [0xE6F5FA, 0xD6EFFA, 0xEBF7FC,
                         0xCCEAF8, 0xE0F4FC, 0xD4EEF9,
                         0xF2F8FB, 0xEEF6FA, 0xF5FAFC]
            case .unlocked:
                hexes = [0xE8F8F1, 0xD9F3E7, 0xEDF9F4,
                         0xCEF0E1, 0xE2F6ED, 0xD6F2E5,
                         0xF3FAF7, 0xEFF8F4, 0xF6FBF9]
            }
        }
        return hexes.map { Color(hex: $0) }
    }

    /// 环境光晕颜色（叠加在 MeshGradient 之上，增加纵深）。
    static func ambientGlow(for state: DoorVisualState, scheme: ColorScheme) -> Color {
        switch (state, scheme) {
        case (.locked, .dark): return Color(hex: 0x2E6BFF).opacity(0.20)
        case (.locked, _): return Color(hex: 0x7EB8FF).opacity(0.28)
        case (.unlocking, .dark): return Color(hex: 0x19B9D8).opacity(0.22)
        case (.unlocking, _): return Color(hex: 0x63D6EE).opacity(0.30)
        case (.unlocked, .dark): return Color(hex: 0x1FD98A).opacity(0.18)
        case (.unlocked, _): return Color(hex: 0x63E6B0).opacity(0.26)
        }
    }

    // MARK: 文本与描边

    static func glassStroke(scheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: scheme == .dark
                ? [Color.white.opacity(0.22), Color.white.opacity(0.04)]
                : [Color.white.opacity(0.85), Color.white.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardShadow(scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.34) : Color(hex: 0x5D7699).opacity(0.14)
    }

    // MARK: 动效曲线

    static let stateSpring = Animation.spring(response: 0.45, dampingFraction: 0.78)
    static let backgroundEase = Animation.easeInOut(duration: 0.85)
}

// MARK: - 颜色工具

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: Int, dark: Int) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - 卡片修饰

struct DormGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var corner: CGFloat = AppTheme.tileCorner
    var interactive: Bool = false
    var shadow: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        content
            .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            .overlay {
                shape.strokeBorder(AppTheme.glassStroke(scheme: scheme), lineWidth: 0.8)
            }
            .shadow(
                color: shadow ? AppTheme.cardShadow(scheme: scheme) : .clear,
                radius: shadow ? 22 : 0,
                x: 0,
                y: shadow ? 10 : 0
            )
    }
}

extension View {
    func dormGlassCard(
        corner: CGFloat = AppTheme.tileCorner,
        interactive: Bool = false,
        shadow: Bool = true
    ) -> some View {
        modifier(DormGlassCard(corner: corner, interactive: interactive, shadow: shadow))
    }
}
