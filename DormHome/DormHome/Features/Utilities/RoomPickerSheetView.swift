//
//  RoomPickerSheetView.swift
//  DormHome
//
//  水电「选择宿舍房间」液态玻璃 Sheet：
//  校区 → 楼栋 → 楼层 → 房间 四级实时级联，选中后立即查询该房间真实水电。
//

import SwiftUI

struct RoomPickerSheetView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var zones: [SWAEZone] = []
    @State private var buildings: [SWAEBuilding] = []
    @State private var floors: [SWAEFloor] = []
    @State private var rooms: [SWAERoomOption] = []

    @State private var selectedZone: SWAEZone?
    @State private var selectedBuilding: SWAEBuilding?
    @State private var selectedFloor: SWAEFloor?

    @State private var isLoadingZones = false
    @State private var loadingStep: Int?
    @State private var queryingRoomID: Int?
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    zoneStep
                    if selectedZone != nil {
                        buildingStep
                    }
                    if selectedBuilding != nil {
                        floorStep
                    }
                    if selectedFloor != nil {
                        roomStep
                    }
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    if let queryingRoomID,
                       let room = rooms.first(where: { $0.id == queryingRoomID }) {
                        queryingBanner(room)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.ultraThinMaterial)
        .interactiveDismissDisabled(queryingRoomID != nil)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await loadZones()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("选择宿舍房间")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("依次选择校区、楼栋、楼层与房间")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                Haptics.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭选房")
        }
    }

    // MARK: - 校区

    private var zoneStep: some View {
        stepCard(index: 1, title: "校区 / 宿舍区", selection: selectedZone?.name, loading: isLoadingZones) {
            if zones.isEmpty, !isLoadingZones {
                emptyHint("暂无可选校区")
            } else {
                optionGrid(items: zones, selected: selectedZone, label: \.name) { zone in
                    selectZone(zone)
                }
            }
        }
    }

    // MARK: - 楼栋

    private var buildingStep: some View {
        stepCard(
            index: 2,
            title: "楼栋",
            selection: selectedBuilding?.name,
            loading: loadingStep == 2
        ) {
            if buildings.isEmpty, loadingStep != 2 {
                emptyHint("该校区暂无可选楼栋")
            } else {
                optionGrid(items: buildings, selected: selectedBuilding, label: \.name) { building in
                    selectBuilding(building)
                }
            }
        }
    }

    // MARK: - 楼层

    private var floorStep: some View {
        stepCard(
            index: 3,
            title: "楼层",
            selection: selectedFloor?.name,
            loading: loadingStep == 3
        ) {
            if floors.isEmpty, loadingStep != 3 {
                emptyHint("该楼栋暂无可选楼层")
            } else {
                optionGrid(items: floors, selected: selectedFloor, label: \.name) { floor in
                    selectFloor(floor)
                }
            }
        }
    }

    // MARK: - 房间

    private var roomStep: some View {
        stepCard(
            index: 4,
            title: "房间",
            selection: selectedFloor == nil ? nil : "点击房间立即查询",
            loading: loadingStep == 4
        ) {
            if rooms.isEmpty, loadingStep != 4 {
                emptyHint("该楼层暂无可选房间")
            } else {
                roomGrid
            }
        }
    }

    private var roomGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(rooms) { room in
                Button {
                    pickRoom(room)
                } label: {
                    ZStack {
                        if queryingRoomID == room.id {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(room.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                queryingRoomID == room.id
                                    ? AppTheme.actionBlue.opacity(0.13)
                                    : Color.primary.opacity(0.045)
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                queryingRoomID == room.id
                                    ? AppTheme.actionBlue.opacity(0.4)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(queryingRoomID != nil)
            }
        }
    }

    // MARK: - 组件

    private func stepCard<Content: View>(
        index: Int,
        title: String,
        selection: String?,
        loading: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(AppTheme.actionBlue))

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Spacer(minLength: 4)

                if loading {
                    ProgressView().controlSize(.small)
                } else if let selection {
                    Text(selection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            content()
        }
        .padding(14)
        .dormGlassCard(corner: 20, shadow: false)
    }

    private func optionGrid<Item: Identifiable & Hashable>(
        items: [Item],
        selected: Item?,
        label: KeyPath<Item, String>,
        onSelect: @escaping (Item) -> Void
    ) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(items) { item in
                let isSelected = selected == item
                Button {
                    onSelect(item)
                } label: {
                    Text(item[keyPath: label])
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(isSelected ? AppTheme.actionBlue : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    isSelected
                                        ? AppTheme.actionBlue.opacity(0.14)
                                        : Color.primary.opacity(0.045)
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? AppTheme.actionBlue.opacity(0.42)
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.dangerRed)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.dangerRed.opacity(0.09))
        }
    }

    private func queryingBanner(_ room: SWAERoomOption) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("正在读取 \(room.name) 实时水电…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .dormGlassCard(corner: 18, shadow: false)
    }

    // MARK: - 数据加载

    private func loadZones() async {
        isLoadingZones = true
        defer { isLoadingZones = false }
        do {
            zones = try await model.loadZones()
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func selectZone(_ zone: SWAEZone) {
        Haptics.impact(.light)
        selectedZone = zone
        selectedBuilding = nil
        selectedFloor = nil
        buildings = []
        floors = []
        rooms = []
        errorMessage = nil

        let zoneID = zone.id
        loadingStep = 2
        Task { @MainActor in
            defer { loadingStep = nil }
            do {
                let result = try await model.loadBuildings(zone: zone)
                guard selectedZone?.id == zoneID else { return }
                buildings = result
            } catch {
                guard selectedZone?.id == zoneID else { return }
                errorMessage = message(for: error)
            }
        }
    }

    private func selectBuilding(_ building: SWAEBuilding) {
        Haptics.impact(.light)
        selectedBuilding = building
        selectedFloor = nil
        floors = []
        rooms = []
        errorMessage = nil

        let buildID = building.id
        loadingStep = 3
        Task { @MainActor in
            defer { loadingStep = nil }
            do {
                let result = try await model.loadFloors(building: building)
                guard selectedBuilding?.id == buildID else { return }
                floors = result
            } catch {
                guard selectedBuilding?.id == buildID else { return }
                errorMessage = message(for: error)
            }
        }
    }

    private func selectFloor(_ floor: SWAEFloor) {
        Haptics.impact(.light)
        selectedFloor = floor
        rooms = []
        errorMessage = nil

        let floorID = floor.id
        loadingStep = 4
        Task { @MainActor in
            defer { loadingStep = nil }
            do {
                let result = try await model.loadRooms(floor: floor)
                guard selectedFloor?.id == floorID else { return }
                rooms = result
            } catch {
                guard selectedFloor?.id == floorID else { return }
                errorMessage = message(for: error)
            }
        }
    }

    private func pickRoom(_ room: SWAERoomOption) {
        guard let zone = selectedZone,
              let building = selectedBuilding,
              let floor = selectedFloor,
              queryingRoomID == nil else {
            return
        }

        Haptics.impact(.medium)
        queryingRoomID = room.id
        errorMessage = nil

        Task { @MainActor in
            defer { queryingRoomID = nil }
            do {
                try await model.selectUtilityRoom(
                    room: room,
                    zone: zone,
                    building: building,
                    floor: floor
                )
                dismiss()
            } catch {
                errorMessage = message(for: error)
                Haptics.notify(.error)
            }
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
