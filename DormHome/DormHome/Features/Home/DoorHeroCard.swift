//
//  DoorHeroCard.swift
//  DormHome
//
//  首页视觉核心：164pt 液态玻璃锁芯、状态光环、双控操作条。
//  严格对应 DESIGN_SPEC §4.2。
//

import SwiftUI

struct DoorHeroCard: View {
    @EnvironmentObject private var model: DormAppModel
    @Environment(\.colorScheme) private var scheme

    private var device: DoorDevice? { model.selectedDevice }
    private var accent: Color { AppTheme.accent(for: model.doorState) }

    var body: some View {
        VStack(spacing: 16) {
            header
            LockOrb(model: model)
            actionBar
            microStatus
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .dormGlassCard(corner: AppTheme.heroCorner)
        .animation(AppTheme.stateSpring, value: model.doorState)
    }

    // MARK: - 顶部信息行

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(device?.name ?? "宿舍门锁")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if model.devices.count > 1 {
                        deviceMenu
                    }
                }

                HStack(spacing: 7) {
                    Circle()
                        .fill((device?.isOnline ?? false) ? AppTheme.onlineGreen : AppTheme.dangerRed)
                        .frame(width: 6, height: 6)
                    Text((device?.isOnline ?? false) ? "在线" : "离线")

                    Text("·").foregroundStyle(.tertiary)

                    Image(systemName: device?.batterySymbol ?? "battery.0percent")
                        .font(.system(size: 12, weight: .medium))
                    Text(device?.battery.map { "\($0)%" } ?? "—")

                    Text("·").foregroundStyle(.tertiary)
                    Text("SN \(serialSuffix)")
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                model.refreshDevices()
            } label: {
                Group {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.glass)
            .disabled(model.isBusy || model.isRefreshing)
            .accessibilityLabel("刷新门锁状态")
        }
    }

    private var serialSuffix: String {
        guard let sn = device?.serialNo, sn.count >= 4 else { return "—" }
        return String(sn.suffix(4))
    }

    private var deviceMenu: some View {
        Menu {
            ForEach(model.devices) { item in
                Button {
                    model.selectDevice(item)
                } label: {
                    Label(
                        item.name,
                        systemImage: item.deviceId == device?.deviceId ? "checkmark" : "door.left.hand.open"
                    )
                }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .accessibilityLabel("切换门锁")
    }

    // MARK: - 双控操作条

    private var actionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    model.unlock()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(model.isUnlocked ? "重新开锁" : "远程开锁")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(accent)
                .disabled(model.isBusy || model.doorState == .unlocking)
                .accessibilityHint("向门锁下发远程开锁指令")

                Button {
                    model.lock()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("上锁")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(model.doorState == .locked ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glass)
                .frame(width: 112)
                .disabled(model.isBusy || model.doorState == .locked)
                .accessibilityHint("立即复位为上锁状态并记录日志")
            }
        }
    }

    // MARK: - 底部微状态

    private var microStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent.opacity(0.9))
            Text(model.microStatus)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 锁芯圆环

private struct LockOrb: View {
    @ObservedObject var model: DormAppModel

    private var accent: Color { AppTheme.accent(for: model.doorState) }
    private var symbol: String {
        switch model.doorState {
        case .locked: return "lock.fill"
        case .unlocking: return "lock.rotation"
        case .unlocked: return "lock.open.fill"
        }
    }

    var body: some View {
        ZStack {
            // 柔和光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.26), accent.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 86
                    )
                )
                .frame(width: 172, height: 172)
                .blur(radius: 10)

            // 外圈细描边
            Circle()
                .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                .frame(width: 164, height: 164)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    if model.doorState == .locked {
                        let breath = 1 + 0.012 * sin(time * 1.3)
                        Circle()
                            .stroke(accent.opacity(0.10), lineWidth: 1)
                            .frame(width: 150, height: 150)
                            .scaleEffect(breath)
                    } else if model.doorState == .unlocking {
                        Circle()
                            .stroke(accent.opacity(0.12), lineWidth: 2.5)
                            .frame(width: 156, height: 156)
                        Circle()
                            .trim(from: 0, to: 0.24)
                            .stroke(
                                AngularGradient(
                                    colors: [.clear, accent.opacity(0.2), accent],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 156, height: 156)
                            .rotationEffect(.degrees((time.truncatingRemainder(dividingBy: 1.6) / 1.6) * 360))
                    } else {
                        let progress = model.relockProgress
                        Circle()
                            .stroke(accent.opacity(0.12), lineWidth: 3)
                            .frame(width: 164, height: 164)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                accent,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 164, height: 164)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.25), value: progress)

                        let phase = time.truncatingRemainder(dividingBy: 2.6) / 2.6
                        Circle()
                            .stroke(accent.opacity(0.22 * (1 - phase)), lineWidth: 1.5)
                            .frame(width: 140 + 26 * phase, height: 140 + 26 * phase)
                            .opacity(1 - phase)
                    }
                }
            }
            .frame(width: 172, height: 172)

            Button {
                model.toggleDoor()
            } label: {
                VStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.hierarchical)
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                        .symbolEffect(.bounce, value: model.doorState)

                    Text(model.statusLabel)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 10)
                }
                .frame(width: 136, height: 136)
                .background {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                }
                .glassEffect(.regular.tint(accent.opacity(0.22)).interactive(), in: .circle)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy && model.doorState == .unlocking)
            .accessibilityLabel("\(model.selectedDevice?.name ?? "宿舍门锁")，\(model.statusLabel)")
            .accessibilityHint("轻点开锁；已开锁时轻点立即上锁")
        }
        .frame(width: 172, height: 172)
    }
}

#Preview {
    let store = DormStore()
    return ZStack {
        AmbientBackgroundView(state: .locked)
        DoorHeroCard()
            .environmentObject(DormAppModel(store: store))
            .environmentObject(store)
            .padding(20)
    }
}
