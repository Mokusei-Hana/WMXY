//
//  AmbientBackgroundView.swift
//  DormHome
//
//  Layer 0：全屏 3×3 MeshGradient 环境光层。
//  随门锁状态在 0.85s 内柔和过渡，并以极慢速度呼吸漂移。
//

import SwiftUI

struct AmbientBackgroundView: View {
    let state: DoorVisualState

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colors: [Color] {
        AppTheme.meshColors(for: state, scheme: scheme)
    }

    var body: some View {
        ZStack {
            if reduceMotion {
                mesh(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    mesh(at: context.date.timeIntervalSinceReferenceDate)
                }
            }

            ambientGlows
            vignette
        }
        .ignoresSafeArea()
        .animation(AppTheme.backgroundEase, value: state)
        .animation(AppTheme.backgroundEase, value: scheme)
    }

    // MARK: - Mesh

    private func mesh(at time: TimeInterval) -> some View {
        let phase = time * 0.085
        let p1 = Float(0.5 + 0.055 * sin(phase))
        let p3 = Float(0.5 + 0.045 * cos(phase * 0.8))
        let p4 = Float(0.5 + 0.06 * sin(phase * 0.65))
        let p5 = Float(0.5 + 0.05 * cos(phase * 0.72))
        let p7 = Float(0.5 + 0.05 * cos(phase * 0.9))

        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2<Float>(0, 0), SIMD2<Float>(p1, 0), SIMD2<Float>(1, 0),
                SIMD2<Float>(0, p3), SIMD2<Float>(p4, p5), SIMD2<Float>(1, p5),
                SIMD2<Float>(0, 1), SIMD2<Float>(p7, 1), SIMD2<Float>(1, 1)
            ],
            colors: colors,
            background: colors.first ?? .clear,
            smoothsColors: true
        )
    }

    // MARK: - 环境光晕

    private var ambientGlows: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let glow = AppTheme.ambientGlow(for: state, scheme: scheme)
            let accent = AppTheme.accent(for: state)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glow, glow.opacity(0.28), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.72
                        )
                    )
                    .frame(width: size.width * 1.7, height: size.width * 1.7)
                    .position(x: size.width * 0.22, y: size.height * 0.28)
                    .blur(radius: 46)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(scheme == .dark ? 0.13 : 0.10), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.55
                        )
                    )
                    .frame(width: size.width * 1.3, height: size.width * 1.3)
                    .position(x: size.width * 0.84, y: size.height * 0.66)
                    .blur(radius: 54)

                // 顶部极轻高光，让标题区域更通透
                LinearGradient(
                    colors: [
                        Color.white.opacity(scheme == .dark ? 0.05 : 0.24),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: size.height * 0.38)
                .frame(maxHeight: .infinity, alignment: .top)
                .blendMode(.plusLighter)
                .opacity(scheme == .dark ? 0.6 : 1)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 暗角

    private var vignette: some View {
        RadialGradient(
            colors: [
                .clear,
                .clear,
                scheme == .dark ? Color.black.opacity(0.34) : Color(hex: 0x8FA6C0).opacity(0.08)
            ],
            center: .center,
            startRadius: 40,
            endRadius: 560
        )
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        AmbientBackgroundView(state: .locked)
        VStack(spacing: 12) {
            Text("宿享").font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Liquid Glass Ambient").font(.callout).foregroundStyle(.secondary)
        }
    }
}
