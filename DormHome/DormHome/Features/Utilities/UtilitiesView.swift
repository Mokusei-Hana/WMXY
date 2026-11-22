//
//  UtilitiesView.swift
//  DormHome
//
//  生活 Tab / 水电费模块 / 空调与一卡通扩展位。
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

    private var modules: [DormServiceModule] {
        ModuleRegistry.enabled(ids: store.enabledModuleIDs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(state: model.doorState)

                ScrollView {
                    VStack(spacing: AppTheme.moduleSpacing) {
                        header
                        UtilitiesContent(showAPI: false)
                        modulesSection
                        comingSoon
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
                Text("\(store.roomName) · 一站式校园生活")
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
            Text("服务模块")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)

            if modules.isEmpty {
                Text("尚未开启服务模块，可在设置中开启")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppTheme.tileSpacing),
                        GridItem(.flexible(), spacing: AppTheme.tileSpacing)
                    ],
                    spacing: AppTheme.tileSpacing
                ) {
                    ForEach(modules) { module in
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

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("扩展中心")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("更多宿舍服务正在接入")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("即将上线")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.055)))
            }

            HStack(spacing: 0) {
                comingSoonItem(symbol: "washer.fill", title: "洗衣房")
                comingSoonItem(symbol: "wrench.and.screwdriver.fill", title: "报修")
                comingSoonItem(symbol: "person.badge.key.fill", title: "访客")
            }
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    private func comingSoonItem(symbol: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.primary.opacity(0.05)))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 水电费独立页面

struct UtilitiesView: View {
    @EnvironmentObject private var model: DormAppModel

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            ScrollView {
                UtilitiesContent(showAPI: true)
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 56)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle("水电费查询")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fontDesign(.rounded)
    }
}

// MARK: - 水电内容

struct UtilitiesContent: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    var showAPI: Bool

    @State private var showRoomPicker = false
    @State private var selectedMeterID: String?

    private var detail: SWAERoomDetail? { store.roomDetail }
    private var isLive: Bool { detail != nil }
    private var isDemoMode: Bool { !store.isLoggedIn && detail == nil }
    private var boundRooms: [SWAERoomSummary] { store.boundRooms }

    private var statusTitle: String {
        if isLive { return "实时数据 · 完美校园 SWAE" }
        return store.isLoggedIn
            ? "未获取实时数据 · 可选择宿舍房间"
            : "演示数据 · 本地体验"
    }

    private var currentRoomName: String {
        if let name = store.selectedRoomName, !name.isEmpty { return name }
        if let name = detail?.roomFullName, !name.isEmpty { return name }
        return store.isLoggedIn ? "尚未选择宿舍" : store.roomName
    }

    var body: some View {
        VStack(spacing: AppTheme.moduleSpacing) {
            if showAPI {
                topBar
            }

            if let detail {
                liveMeterSection(detail)
                usageSection(detail)
                if let meter = detail.primaryMeter,
                   let days = meter.estimatedDays,
                   days <= 7 {
                    lowBalanceCard(detail: detail, meter: meter, days: days)
                }
            } else {
                if isDemoMode {
                    demoBalanceSection
                    demoChartSection
                } else {
                    emptyRoomState
                }
                roomPickerPrompt
            }

            sourceCard
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

    // MARK: 顶部栏

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isLive ? AppTheme.onlineGreen : AppTheme.warningAmber)
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: (isLive ? AppTheme.onlineGreen : AppTheme.warningAmber).opacity(0.55),
                            radius: 4
                        )
                    Text(statusTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

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
                            Label("选择其他宿舍房间…", systemImage: "building.2")
                        }
                    } label: {
                        roomTitle(showChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    roomTitle(showChevron: false)
                }
            }

            Spacer(minLength: 4)

            glassButton(
                symbol: "building.2.fill",
                title: "选房",
                label: "选择宿舍房间",
                busy: false
            ) {
                Haptics.impact(.light)
                showRoomPicker = true
            }

            glassButton(
                symbol: "arrow.clockwise",
                title: "刷新",
                label: "刷新实时水电",
                busy: model.isUtilitiesLoading
            ) {
                Task { await model.refreshUtilities() }
            }
        }
    }

    private func roomTitle(showChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(currentRoomName)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
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

    private func glassButton(
        symbol: String,
        title: String,
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }

    // MARK: 实时表计

    private func liveMeterSection(_ detail: SWAERoomDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("实时表计")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                statusBadge("实时", tint: AppTheme.onlineGreen)
                Spacer()
                Text(store.lastUtilitySyncText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)

            if detail.meters.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("该房间暂未返回表计数据")
                        .font(.system(size: 13, weight: .medium))
                    Text("可稍后刷新，或在完美校园完成房间绑定")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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
                        SWAEMeterCard(meter: meter, kind: detail.kind(for: meter))
                    }
                }
            }
        }
    }

    // MARK: 趋势

    private func usageSection(_ detail: SWAERoomDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if detail.meters.count > 1 {
                meterSelector(detail)
            }

            if let meter = chartMeter(in: detail) {
                UsageChartCard(
                    title: chartTitle(for: detail.kind(for: meter)),
                    subtitle: "\(meter.deviceName) · 近 7 日均值",
                    points: meter.weekUseList,
                    unit: detail.kind(for: meter).unit,
                    tint: detail.kind(for: meter).tint
                )
            }
        }
    }

    private func meterSelector(_ detail: SWAERoomDetail) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(detail.meters) { meter in
                    let kind = detail.kind(for: meter)
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
                            Text(meter.deviceName)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selected ? kind.tint : Color.secondary)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background {
                            Capsule(style: .continuous)
                                .fill(
                                    selected
                                        ? kind.tint.opacity(0.15)
                                        : Color.primary.opacity(0.045)
                                )
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    selected ? kind.tint.opacity(0.42) : .clear,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("演示账单")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                statusBadge("演示数据", tint: AppTheme.warningAmber)
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: AppTheme.tileSpacing) {
                BalanceCard(
                    title: "剩余电量",
                    value: String(format: "%.1f", store.electricityKWh),
                    unit: "kWh",
                    caption: "约可用 \(store.estimatedElectricityDays) 天",
                    fraction: min(1, store.electricityKWh / 100),
                    tint: AppTheme.electricYellow,
                    symbol: "bolt.fill",
                    fractionCaption: "\(Int(min(100, store.electricityKWh)))%"
                )

                BalanceCard(
                    title: "水费余额",
                    value: String(format: "¥%.2f", store.waterBalance),
                    unit: "",
                    caption: "本月用水 3.2 m³",
                    fraction: min(1, store.waterBalance / 50),
                    tint: AppTheme.waterBlue,
                    symbol: "drop.fill",
                    fractionCaption: "\(Int(store.waterBalance / 50 * 100))%"
                )
            }
        }
    }

    private var demoChartSection: some View {
        UsageChartCard(
            title: "近 7 日用电",
            subtitle: "演示用量 · 日均 \(String(format: "%.1f", store.averageElectricity)) kWh",
            points: demoUsagePoints,
            unit: "kWh",
            tint: AppTheme.electricYellow
        )
    }

    private var demoUsagePoints: [SWAEDailyUsage] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd"
        return store.electricityUsage.map {
            SWAEDailyUsage(dateText: formatter.string(from: $0.date), use: $0.kwh)
        }
    }

    private var emptyRoomState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(AppTheme.warningAmber.opacity(0.14))
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.warningAmber)
            }
            .frame(width: 48, height: 48)

            Text("尚未获取实时水电")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text("当前账号未返回已绑定房间。你可以直接选择宿舍房间，读取该房间的实时水电。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    private var roomPickerPrompt: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.actionBlue.opacity(0.14))
                Image(systemName: "building.2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.actionBlue)
            }
            .frame(width: 48, height: 48)

            VStack(spacing: 4) {
                Text("选择你的宿舍房间")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("校区 → 楼栋 → 楼层 → 房间，直接查询真实水电；若该房间尚未绑定表计，会提示先前往完美校园绑定。")
                    .font(.system(size: 11))
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

            if !store.isLoggedIn {
                Text("未登录也可选房查询 · 登录后将自动同步已绑定房间")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }

    // MARK: 低余量提醒

    private func lowBalanceCard(
        detail: SWAERoomDetail,
        meter: SWAEMeterDetail,
        days: Int
    ) -> some View {
        let kind = detail.kind(for: meter)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.warningAmber.opacity(0.16))
                Image(systemName: "bolt.badge.clock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.warningAmber)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("低余量提醒")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(meter.deviceName) 约可用 \(days) 天，建议及时充值")
                    .font(.system(size: 11))
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

    // MARK: 数据来源尾卡

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.waterBlue)

                Text(model.utilityConfig?.systemName ?? SWAEClient.systemName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer()

                statusBadge(
                    isLive ? "实时" : (store.isLoggedIn ? "未同步" : "演示"),
                    tint: isLive ? AppTheme.onlineGreen : AppTheme.warningAmber
                )
            }

            Text(feeLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(store.lastUtilitySyncText)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("只读查询 · 不产生交易")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    private var feeLine: String {
        let config = model.utilityConfig
        let electric = priceText(config?.electricityUnitPrice ?? 0.65)
        let cold = priceText(config?.coldWaterUnitPrice ?? 1.5)
        let hot = priceText(config?.hotWaterUnitPrice ?? 2.5)
        return "学校代码 2502 · 电 \(electric)元/度 · 冷水 \(cold)元/吨 · 热水 \(hot)元/吨"
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

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter.string(from: Date())
    }

    private func statusBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(tint.opacity(0.13)))
    }
}

// MARK: - 表计卡片

private struct SWAEMeterCard: View {
    let meter: SWAEMeterDetail
    let kind: SWAEMeterKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle().fill(kind.tint.opacity(0.16))
                    Image(systemName: kind.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(kind.tint)
                }
                .frame(width: 32, height: 32)

                Spacer(minLength: 2)

                Text(meter.isOn ? kind.statusOnText : kind.statusOffText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(meter.isOn ? AppTheme.onlineGreen : AppTheme.dangerRed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                (meter.isOn ? AppTheme.onlineGreen : AppTheme.dangerRed)
                                    .opacity(0.13)
                            )
                    }
            }

            Text(meter.deviceName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(meter.remaining.swaeText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                if !kind.unit.isEmpty {
                    Text(kind.unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 1)

            HStack(spacing: 4) {
                Text("今日 \(meter.todayUse.swaeText) \(kind.unit)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("·")
                if let days = meter.estimatedDays {
                    Text("约可用 \(days) 天")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("用量稳定")
                        .lineLimit(1)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.top, 5)

            if hasBreakdown {
                Divider().opacity(0.35).padding(.top, 8)
                HStack(spacing: 6) {
                    if let subsidy = meter.sumSub, subsidy > 0 {
                        Text("补贴 \(subsidy.swaeText)")
                    }
                    if let purchase = meter.sumBuy, purchase > 0 {
                        Text("自购 \(purchase.swaeText)")
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }

    private var hasBreakdown: Bool {
        (meter.sumSub ?? 0) > 0 || (meter.sumBuy ?? 0) > 0
    }
}

// MARK: - 用量图

private struct UsageChartCard: View {
    let title: String
    let subtitle: String
    let points: [SWAEDailyUsage]
    let unit: String
    let tint: Color

    private var total: Double { points.reduce(0) { $0 + $1.use } }
    private var average: Double {
        guard !points.isEmpty else { return 0 }
        return total / Double(points.count)
    }
    private var maxValue: Double {
        max(1, (points.map(\.use).max() ?? 1) * 1.25)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(points.isEmpty ? subtitle : "\(subtitle) · 日均 \(average.swaeText) \(unit)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(total.swaeText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

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
                .frame(height: 132)
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("日期", point.shortDateText),
                            y: .value("用量", point.use)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.34), tint.opacity(0.02)],
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
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))

                        PointMark(
                            x: .value("日期", point.shortDateText),
                            y: .value("用量", point.use)
                        )
                        .foregroundStyle(tint)
                        .symbolSize(16)
                    }

                    if average > 0 {
                        RuleMark(y: .value("日均", average))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...maxValue)
                .chartLegend(.hidden)
                .frame(height: 142)
            }
        }
        .padding(18)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }
}

// MARK: - 余额卡片

private struct BalanceCard: View {
    let title: String
    let value: String
    let unit: String
    let caption: String
    let fraction: Double
    let tint: Color
    let symbol: String
    let fractionCaption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)

                Spacer()

                Text(fractionCaption)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 1)

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
        .frame(height: 154)
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
                    integrationNote
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
                        Text("网关未连接")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("即将接入")
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
                model.showToast("空调网关接入后即可远程预冷", style: .info)
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

    private var integrationNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("模块化扩展位", systemImage: "puzzlepiece.extension.fill")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text("空调控温将通过宿舍网关或红外桥接接入。接口预留后，可在回寝前远程预冷、定时关机，并与门锁开锁事件联动。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("POST")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.climateBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(AppTheme.climateBlue.opacity(0.12)))
                Text("/dorm/climate/control")
                    .font(.system(size: 11, design: .monospaced))
                Spacer()
                Text("待接入").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }
}

// MARK: - 校园一卡通扩展位

struct CampusCardView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    private let transactions: [(String, String, String)] = [
        ("食堂 · 三楼档口", "今天 12:08", "-12.50"),
        ("校园超市", "昨天 19:42", "-8.90"),
        ("热水充值", "11月20日", "+30.00")
    ]

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            ScrollView {
                VStack(spacing: AppTheme.moduleSpacing) {
                    cardVisual
                    transactionsCard
                    integrationNote
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
                    Text("DORM CAMPUS CARD")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                }
                Spacer()
                Text("即将接入")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.16)))
            }
            .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 18)

            Text("校园卡余额")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("¥")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(String(format: "%.2f", store.cardBalance))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)

            Spacer(minLength: 16)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.userName ?? "宿享用户")
                        .font(.system(size: 12, weight: .semibold))
                    Text("**** **** **** 0412")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
        }
        .padding(22)
        .frame(height: 218)
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

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近期流水")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Text("演示数据")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(transactions.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(AppTheme.campusPurple.opacity(0.14))
                        Image(systemName: item.2.hasPrefix("+") ? "arrow.down.left" : "fork.knife")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.campusPurple)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(.system(size: 13, weight: .medium))
                        Text(item.1)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.2)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(item.2.hasPrefix("+") ? AppTheme.onlineGreen : Color.primary)
                }

                if index < transactions.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }

    private var integrationNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("模块化扩展位", systemImage: "creditcard.fill")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.campusPurple)
            Text("接入校园一卡通后，可查询实时余额、消费流水，并在余额不足时提醒充值。当前展示为演示数据。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("充值") {
                    model.showToast("一卡通充值将在接入后开放", style: .info)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)

                Button("挂失") {
                    model.showToast("挂失入口将在接入后开放", style: .info)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
    }
}
