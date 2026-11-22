//
//  ServiceTileView.swift
//  DormHome
//
//  Apple Home Bento 风格服务瓷砖，严格对应 DESIGN_SPEC §4.3。
//

import SwiftUI

struct ServiceTileView: View {
    let module: DormServiceModule
    let value: String
    let detail: String

    var body: some View {
        NavigationLink(value: module) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(module.tint.opacity(0.16))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(module.tint.opacity(0.12), lineWidth: 0.5)
                        Image(systemName: module.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(module.tint)
                    }
                    .frame(width: 36, height: 36)

                    Spacer(minLength: 4)

                    if let badge = module.badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.055))
                            }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 3) {
                    Text(module.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text(detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 3)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            .dormGlassCard(corner: AppTheme.tileCorner, interactive: true)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.tileCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(module.title)，\(value)，\(detail)")
    }
}

#Preview {
    NavigationStack {
        ZStack {
            AmbientBackgroundView(state: .locked)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(ModuleRegistry.all) { module in
                    ServiceTileView(module: module, value: "42.6 kWh", detail: "约可用 12 天")
                }
            }
            .padding(20)
        }
    }
}
