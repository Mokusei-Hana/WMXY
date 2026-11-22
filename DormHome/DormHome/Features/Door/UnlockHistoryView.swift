//
//  UnlockHistoryView.swift
//  DormHome
//
//  本地开门 / 上锁记录，按日期分组展示。
//

import SwiftUI

struct UnlockHistoryView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel

    @State private var showClearConfirm = false

    private var groups: [(day: Date, records: [UnlockRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.history) { calendar.startOfDay(for: $0.date) }
        return grouped.keys
            .sorted(by: >)
            .map { day in
                (day, (grouped[day] ?? []).sorted { $0.date > $1.date })
            }
    }

    var body: some View {
        ZStack {
            AmbientBackgroundView(state: model.doorState)

            if store.history.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: AppTheme.moduleSpacing) {
                        summaryCard
                        ForEach(groups, id: \.day) { group in
                            daySection(group.day, records: group.records)
                        }
                        Text("记录仅保存在本机，可通过清除操作删除。")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 56)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle("开门记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(store.history.isEmpty)
                .accessibilityLabel("清空开门记录")
            }
        }
        .confirmationDialog("清空全部开门记录？", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空记录", role: .destructive) {
                store.clearHistory()
                Haptics.notify(.success)
                model.showToast("开门记录已清空", style: .info)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销，仅清除本机记录。")
        }
        .fontDesign(.rounded)
    }

    // MARK: - 概览

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryMetric(
                value: "\(store.unlockThisWeekCount)",
                label: "本周开锁",
                tint: AppTheme.onlineGreen
            )
            divider
            summaryMetric(
                value: "\(store.history.filter { $0.channel == .autoRelock }.count)",
                label: "自动回锁",
                tint: AppTheme.actionBlue
            )
            divider
            summaryMetric(
                value: lastActivityShort,
                label: "最近操作",
                tint: AppTheme.warningAmber
            )
        }
        .padding(.vertical, 16)
        .dormGlassCard(corner: AppTheme.tileCorner)
    }

    private func summaryMetric(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(width: 1, height: 30)
    }

    private var lastActivityShort: String {
        guard let date = store.history.first?.date else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - 分组

    private func daySection(_ day: Date, records: [UnlockRecord]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayTitle(day))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(records.count) 条")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    HistoryRow(record: record)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteHistory(record)
                                Haptics.impact(.light)
                            } label: {
                                Label("删除这条记录", systemImage: "trash")
                            }
                        }

                    if index < records.count - 1 {
                        Divider()
                            .opacity(0.4)
                            .padding(.leading, 58)
                    }
                }
            }
            .dormGlassCard(corner: AppTheme.tileCorner, shadow: false)
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.onlineGreen.opacity(0.12))
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AppTheme.onlineGreen)
            }
            .frame(width: 72, height: 72)

            Text("暂无开门记录")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            Text("每次远程开锁与自动回锁都会记录在这里")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .dormGlassCard(corner: AppTheme.heroCorner)
        .padding(.horizontal, 40)
    }
}

// MARK: - 单条记录

private struct HistoryRow: View {
    let record: UnlockRecord

    private var tint: Color {
        record.action == .unlock ? AppTheme.onlineGreen : AppTheme.actionBlue
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                Image(systemName: record.action.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(record.action.title)\(record.success ? "成功" : "失败")")
                        .font(.system(size: 13, weight: .semibold))
                    if record.isDemo {
                        Text("演示")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                    }
                }

                Text(record.deviceName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(timeText)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                Text(record.channel.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: record.date)
    }
}
