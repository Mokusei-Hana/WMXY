//
//  UtilitiesView.swift
//  DormHome
//
//  生活 Tab / 水电费查询 / 扩展模块。
//

import SwiftUI
import Charts

// MARK: - 模块路由

struct ModuleDestinationView: View {
    let module: DormServiceModule

    var body: some View {
        switch module.kind {
        case .utilities:
            UtilitiesView()
        case .history:
            UnlockHistoryView()
        case .climate:
            ClimateControlView()
        case .campusCard:
            CampusCardView()
        }
    }
}

// MARK: - 生活 Tab

struct LifeView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    /// 生活页顶部已完整呈现水电，下方仅展示其他已开启的服务模块。
    private var otherModules: [DormServiceModule] {
        ModuleRegistry.enabled(ids: store.enabledModuleIDs)
            .filter { $0.kind != .utilities }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(state: model.doorState)

                ScrollView {
                    VStack(spacing: AppTheme.moduleSpacing) {
                        header
                        UtilitiesContent(showRoomBar: true)
                        if !otherModules.isEmpty {
                            modulesSection
                        }
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 56)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .navigationDestination(for: DormServiceModule.self) { module in
                ModuleDestinationView(module: module)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fontDesign(.rounded)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.roomName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("生活")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(AppTheme.stateSpring) {
                    model.selectedTab = .settings
                }
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .semibold))
                    Text("管理")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("管理生活服务模块")
        }
    }

    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("更多服务")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppTheme.tileSpacing),
                    GridItem(.flexible(), spacing: AppTheme.tileSpacing)
                ],
                spacing: AppTheme.tileSpacing
            ) {
                ForEach(otherModules) { module in
                    ServiceTileView(
                        module: module,
                        value: model.value(for: module),
                        detail: model.detail(for: module)
                    )
                }
            }
        }
    }
}

// MARK: - 水电费独立页面

struct UtilitiesView: View {
    @EnvironmentObject private var model: DormAppModel

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            ScrollView {
                UtilitiesContent(showRoomBar: true)
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 56)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle("水电费")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fontDesign(.rounded)
    }
}

// MARK: - 水电内容

struct UtilitiesContent: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    var showRoomBar: Bool = true

    @State private var showRoomPicker = false
    @State private var selectedMeterID: String?

    private var detail: SWAERoomDetail? { store.roomDetail }
    private var isLive: Bool { detail != nil }
    private var isDemoMode: Bool { store.isDemoMode && detail == nil }
    private var boundRooms: [SWAERoomSummary] { store.boundRooms }

    private var currentRoomName: String {
        if let name = store.selectedRoomName, !name.isEmpty { return name }
        if let name = detail?.roomFullName, !name.isEmpty { return name }
        return isDemoMode ? "3栋 412" : "水电余量"
    }

    private var subtitleText: String {
        if isLive { return store.lastUtilitySyncText }
        if isDemoMode { return "演示数据" }
        return "选择宿舍查看余量"
    }

    var body: some View {
        VStack(spacing: AppTheme.moduleSpacing) {
            if showRoomBar {
                roomBar
            }

            if let detail {
                liveMeterSection(detail)
                usageSection(detail)
                if let meter = detail.primaryMeter,
                   let days = meter.estimatedDays,
                   days <= 7 {
                    lowBalanceCard(detail: detail, meter: meter, days: days)
                }
                tariffFootnote
            } else if isDemoMode {
                demoBalanceSection
                demoChartSection
                roomPickerPrompt
            } else {
                roomPickerPrompt
            }
        }
        .sheet(isPresented: $showRoomPicker) {
            RoomPickerSheetView()
                .environmentObject(store)
                .environmentObject(model)
        }
        .onChange(of: detail?.roomVerify) { _, _ in
            selectedMeterID = nil
        }
    }

    // MARK: 房间栏

    private var roomBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if boundRooms.count > 1 {
                    Menu {
                        ForEach(boundRooms) { room in
                            Button {
                                Haptics.impact(.light)
                                model.selectUtilityRoom(room)
                            } label: {
                                if room.roomVerify == store.selectedRoomVerify {
                                    Label(room.roomFullName, systemImage: "checkmark")
                                } else {
                                    Text(room.roomFullName)
                                }
                            }
                        }
                        Divider()
                        Button {
                            showRoomPicker = true
                        } label: {
                            Label("选择其他宿舍…", systemImage: "building.2")
                        }
                    } label: {
                        roomTitle(showChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    roomTitle(showChevron: false)
                }

                Text(subtitleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            glassActionButton(
                symbol: "building.2",
                title: "选房",
                label: "选择宿舍房间",
                busy: false
            ) {
                Haptics.impact(.light)
                showRoomPicker = true
            }

            if isLive || store.isLoggedIn {
                glassActionButton(
                    symbol: "arrow.clockwise",
                    title: nil,
                    label: "刷新水电数据",
                    busy: model.isUtilitiesLoading
                ) {
                    Task { await model.refreshUtilities() }
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func roomTitle(showChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(currentRoomName)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.primary)

            if showChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func glassActionButton(
        symbol: String,
        title: String?,
        label: String,
        busy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if busy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, title == nil ? 0 : 12)
            .frame(minWidth: 34, minHeight: 34)
            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }

    // MARK: 表计卡片

    private func liveMeterSection(_ detail: SWAERoomDetail) -> some View {
        Group {
            if detail.meters.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("暂无表计数据")
                        .font(.system(size: 14, weight: .semibold))
                    Text("可稍后刷新或切换其他宿舍")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppTheme.tileSpacing),
                        GridItem(.flexible(), spacing: AppTheme.tileSpacing)
                    ],
                    spacing: AppTheme.tileSpacing
                ) {
                    ForEach(detail.meters) { meter in
                        SWAEMeterCard(
                            title: detail.displayName(for: meter),
                            meter: meter,
                            kind: detail.kind(for: meter)
                        )
                    }
                }
            }
        }
    }

    // MARK: 趋势图

    private func usageSection(_ detail: SWAERoomDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if detail.meters.count > 1 {
                meterSelector(detail)
            }

            if let meter = chartMeter(in: detail) {
                let kind = detail.kind(for: meter)
                let meterName = detail.displayName(for: meter)
                UsageChartCard(
                    title: chartTitle(for: kind),
                    meterName: meterName,
                    points: meter.weekUseList,
                    unit: kind.unit,
                    tint: kind.tint
                )
            }
        }
    }

    private func meterSelector(_ detail: SWAERoomDetail) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(detail.meters) { meter in
                    let kind = detail.kind(for: meter)
                    let name = detail.displayName(for: meter)
                    let selected = chartMeter(in: detail)?.id == meter.id
                    Button {
                        withAnimation(AppTheme.stateSpring) {
                            selectedMeterID = meter.id
                        }
                        Haptics.impact(.light)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 10, weight: .semibold))
                            Text(name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selected ? kind.tint : Color.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background {
                            Capsule(style: .continuous)
                                .fill(
                                    selected
                                        ? kind.tint.opacity(0.15)
                                        : Color.primary.opacity(0.05)
                                )
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    selected ? kind.tint.opacity(0.4) : .clear,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chartMeter(in detail: SWAERoomDetail) -> SWAEMeterDetail? {
        if let selectedMeterID,
           let meter = detail.meters.first(where: { $0.id == selectedMeterID }) {
            return meter
        }
        return detail.meters.first(where: { !$0.weekUseList.isEmpty }) ?? detail.meters.first
    }

    private func chartTitle(for kind: SWAEMeterKind) -> String {
        switch kind {
        case .electricity, .airConditioner: return "近 7 日用电"
        case .coldWater, .hotWater: return "近 7 日用水"
        case .other: return "近 7 日用量"
        }
    }

    // MARK: 演示数据

    private var demoBalanceSection: some View {
        HStack(spacing: AppTheme.tileSpacing) {
            BalanceCard(
                title: "电表",
                value: String(format: "%.1f", store.electricityKWh),
                unit: "kWh",
                caption: "约可用 \(store.estimatedElectricityDays) 天",
                fraction: min(1, store.electricityKWh / 100),
                tint: AppTheme.electricYellow,
                symbol: "bolt.fill"
            )

            BalanceCard(
                title: "水表",
                value: String(format: "%.1f", store.waterBalance),
                unit: "t",
                caption: "本月用水 3.2 t",
                fraction: min(1, store.waterBalance / 30),
                tint: AppTheme.waterBlue,
                symbol: "drop.fill"
            )
        }
    }

    private var demoChartSection: some View {
        UsageChartCard(
            title: "近 7 日用电",
            meterName: "电表",
            points: demoUsagePoints,
            unit: "kWh",
            tint: AppTheme.electricYellow
        )
    }

    private var demoUsagePoints: [SWAEDailyUsage] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd"
        let weekFormatter = DateFormatter()
        weekFormatter.locale = Locale(identifier: "zh_CN")
        weekFormatter.dateFormat = "EEE"
        return store.electricityUsage.map {
            SWAEDailyUsage(
                dateText: formatter.string(from: $0.date),
                weekday: weekFormatter.string(from: $0.date),
                use: $0.kwh
            )
        }
    }

    // MARK: 选房引导

    private var roomPickerPrompt: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.electricYellow.opacity(0.14))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.electricYellow)
            }
            .frame(width: 52, height: 52)

            VStack(spacing: 5) {
                Text("查看宿舍水电")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("选择所在校区与宿舍号，即可查看剩余电量和近 7 日用量")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.impact(.medium)
                showRoomPicker = true
            } label: {
                Label("选择宿舍房间", systemImage: "building.2")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.actionBlue)
        }
        .padding(20)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }

    // MARK: 低余量提醒

    private func lowBalanceCard(
        detail: SWAERoomDetail,
        meter: SWAEMeterDetail,
        days: Int
    ) -> some View {
        let kind = detail.kind(for: meter)
        let name = detail.displayName(for: meter)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.warningAmber.opacity(0.16))
                Image(systemName: "bolt.badge.clock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.warningAmber)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("余量偏低")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(name)约可用 \(days) 天，记得及时充值")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            Text("\(meter.remaining.swaeText) \(kind.unit)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.warningAmber)
        }
        .padding(14)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    // MARK: 资费标准注脚

    private var tariffFootnote: some View {
        Text(feeLine)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }

    private var feeLine: String {
        let config = model.utilityConfig
        let electric = priceText(config?.electricityUnitPrice ?? 0.65)
        let cold = priceText(config?.coldWaterUnitPrice ?? 1.5)
        let hot = priceText(config?.hotWaterUnitPrice ?? 2.5)
        return "电 \(electric)元/度 · 冷水 \(cold)元/吨 · 热水 \(hot)元/吨"
    }

    private func priceText(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        if (value * 10).rounded() == value * 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - 表计卡片

private struct SWAEMeterCard: View {
    let title: String
    let meter: SWAEMeterDetail
    let kind: SWAEMeterKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle().fill(kind.tint.opacity(0.16))
                    Image(systemName: kind.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(kind.tint)
                }
                .frame(width: 32, height: 32)

                Spacer(minLength: 2)

                HStack(spacing: 4) {
                    Circle()
                        .fill(meter.isOn ? AppTheme.onlineGreen : AppTheme.dangerRed)
                        .frame(width: 5, height: 5)
                    Text(meter.isOn ? kind.statusOnText : kind.statusOffText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(meter.isOn ? AppTheme.onlineGreen : AppTheme.dangerRed)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            (meter.isOn ? AppTheme.onlineGreen : AppTheme.dangerRed)
                                .opacity(0.12)
                        )
                }
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 10)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(meter.remaining.swaeText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                if !kind.unit.isEmpty {
                    Text(kind.unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)

            HStack(spacing: 4) {
                Text("今日 \(meter.todayUse.swaeText)\(kind.unit)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let days = meter.estimatedDays {
                    Text("·")
                    Text("约 \(days) 天")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.top, 6)

            if hasBreakdown {
                Divider().opacity(0.35).padding(.top, 8)
                HStack(spacing: 8) {
                    if let subsidy = meter.sumSub, subsidy > 0 {
                        Text("补贴 \(subsidy.swaeText)")
                    }
                    if let purchase = meter.sumBuy, purchase > 0 {
                        Text("自购 \(purchase.swaeText)")
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    private var hasBreakdown: Bool {
        (meter.sumSub ?? 0) > 0 || (meter.sumBuy ?? 0) > 0
    }
}

// MARK: - 可交互用量曲线图

private struct UsageChartCard: View {
    let title: String
    let meterName: String
    let points: [SWAEDailyUsage]
    let unit: String
    let tint: Color

    @State private var selectedDate: String?
    @Environment(\.colorScheme) private var scheme

    private var total: Double { points.reduce(0) { $0 + $1.use } }
    private var average: Double {
        guard !points.isEmpty else { return 0 }
        return total / Double(points.count)
    }
    private var maxValue: Double {
        max(1, (points.map(\.use).max() ?? 1) * 1.28)
    }

    private var selectedPoint: SWAEDailyUsage? {
        guard let selectedDate else { return nil }
        return points.first { $0.shortDateText == selectedDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            if points.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("暂无近 7 日用量")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 148)
            } else {
                interactiveChart
            }
        }
        .padding(18)
        .dormGlassCard(corner: AppTheme.tileCorner)
        .onChange(of: points.map(\.shortDateText)) { _, _ in
            selectedDate = nil
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            if newValue != nil, newValue != oldValue {
                Haptics.impact(.light)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                if let selected = selectedPoint {
                    Text(selectedDateLabel(selected))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                } else {
                    Text(points.isEmpty ? meterName : "\(meterName) · 日均 \(average.swaeText) \(unit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text((selectedPoint?.use ?? total).swaeText)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(selectedPoint != nil ? tint : .primary)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(selectedPoint != nil ? "当日用量" : "近 7 日合计")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: selectedDate)
    }

    private var interactiveChart: some View {
        VStack(spacing: 8) {
            Chart {
                ForEach(points) { point in
                    let isSelected = selectedPoint?.id == point.id

                    AreaMark(
                        x: .value("日期", point.shortDateText),
                        y: .value("用量", point.use)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.32), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日期", point.shortDateText),
                        y: .value("用量", point.use)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("日期", point.shortDateText),
                        y: .value("用量", point.use)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(isSelected ? 78 : 22)
                }

                if average > 0, selectedPoint == nil {
                    RuleMark(y: .value("日均", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }

                if let selected = selectedPoint {
                    RuleMark(x: .value("日期", selected.shortDateText))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                        .foregroundStyle(tint.opacity(0.65))
                        .annotation(
                            position: .top,
                            spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            HStack(spacing: 4) {
                                Text(selected.shortDateText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(selected.use.swaeText) \(unit)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(tint)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(scheme == .dark ? Color(hex: 0x162236) : Color.white)
                                    .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 8, y: 3)
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(tint.opacity(0.35), lineWidth: 0.8)
                            }
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            let highlighted = selectedDate == label
                            Text(label)
                                .font(.system(size: 10, weight: highlighted ? .bold : .medium))
                                .foregroundStyle(highlighted ? tint : Color.secondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...maxValue)
            .chartLegend(.hidden)
            .frame(height: 160)
            .padding(.top, 12)

            if selectedPoint == nil {
                Text("滑动曲线查看每日用量")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func selectedDateLabel(_ point: SWAEDailyUsage) -> String {
        if let weekday = point.weekday, !weekday.isEmpty {
            return "\(point.shortDateText) · \(weekday)"
        }
        return point.shortDateText
    }
}

// MARK: - 演示余额卡片

private struct BalanceCard: View {
    let title: String
    let value: String
    let unit: String
    let caption: String
    let fraction: Double
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle().fill(tint.opacity(0.16))
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)

            Spacer(minLength: 8)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.13))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 4)
            .padding(.top, 8)

            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .frame(height: 152)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }
}

// MARK: - 水电显示辅助

private extension SWAEMeterKind {
    var tint: Color {
        switch self {
        case .electricity: return AppTheme.electricYellow
        case .coldWater: return AppTheme.waterBlue
        case .hotWater: return Color(light: 0xFF8A5C, dark: 0xFFA07A)
        case .airConditioner: return AppTheme.climateBlue
        case .other: return Color.secondary
        }
    }
}

private extension Double {
    var swaeText: String {
        if self == rounded() {
            return String(format: "%.0f", self)
        }
        if abs(self) >= 1000 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}

// MARK: - 空调控温扩展位

struct ClimateControlView: View {
    @EnvironmentObject private var model: DormAppModel
    @State private var mode = "制冷"

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            ScrollView {
                VStack(spacing: AppTheme.moduleSpacing) {
                    climateCard
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 56)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("空调控温")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fontDesign(.rounded)
    }

    private var climateCard: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("宿舍空调")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.warningAmber).frame(width: 6, height: 6)
                        Text("未连接")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("即将支持")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.055)))
            }

            ZStack {
                Circle()
                    .stroke(AppTheme.climateBlue.opacity(0.12), lineWidth: 12)
                    .frame(width: 190, height: 190)
                Circle()
                    .trim(from: 0, to: 0.62)
                    .stroke(
                        AppTheme.climateBlue,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("26")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("设定温度 °C")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                ForEach(["制冷", "制热", "除湿"], id: \.self) { item in
                    Button {
                        withAnimation(AppTheme.stateSpring) { mode = item }
                        Haptics.impact(.light)
                    } label: {
                        Text(item)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background {
                        Capsule(style: .continuous)
                            .fill(mode == item ? AppTheme.climateBlue.opacity(0.16) : Color.primary.opacity(0.045))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                mode == item ? AppTheme.climateBlue.opacity(0.45) : Color.clear,
                                lineWidth: 1
                            )
                    }
                    .foregroundStyle(mode == item ? AppTheme.climateBlue : Color.secondary)
                }
            }

            Button {
                model.showToast("空调控制功能即将开放", style: .info)
            } label: {
                Label("连接空调", systemImage: "air.conditioner.horizontal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.climateBlue)
        }
        .padding(22)
        .dormGlassCard(corner: AppTheme.heroCorner)
    }
}

// MARK: - 校园一卡通扩展位

struct CampusCardView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            ScrollView {
                VStack(spacing: AppTheme.moduleSpacing) {
                    cardVisual
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 56)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("校园一卡通")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fontDesign(.rounded)
    }

    private var cardVisual: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("校园一卡通")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                Spacer()
                Text("即将支持")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.18)))
            }
            .foregroundStyle(.white.opacity(0.92))

            Spacer(minLength: 18)

            Text("卡内余额")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("¥")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(store.isDemoMode ? String(format: "%.2f", store.cardBalance) : "—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)

            Spacer(minLength: 16)

            HStack {
                Text(store.userName ?? "未登录")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
        }
        .padding(22)
        .frame(height: 210)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.heroCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x7B3FE4), Color(hex: 0xAF52DE), Color(hex: 0x5E5CE6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.heroCorner, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
        }
        .shadow(color: AppTheme.campusPurple.opacity(0.28), radius: 22, y: 10)
    }
}
