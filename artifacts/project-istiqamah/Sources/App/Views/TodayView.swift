import Combine
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var selectedKey: String { DateTools.key(store.selectedDate) }
    private var isToday: Bool { selectedKey == DateTools.key(Date()) }

    private var selectedSchedule: [ScheduledBlock] {
        store.blocks.compactMap { block in
            guard let window = DateTools.window(for: block, on: store.selectedDate) else { return nil }
            return ScheduledBlock(
                block: block,
                dateKey: DateTools.key(window.start),
                start: window.start,
                end: window.end
            )
        }.sorted { $0.start < $1.start }
    }

    private var focus: ScheduledBlock? {
        if let requestedBlockID = store.requestedBlockID,
           let requested = selectedSchedule.first(where: { $0.block.id == requestedBlockID }) {
            return requested
        }
        if isToday, let active = DateTools.activeBlock(in: store.blocks, at: now) {
            return active
        }
        let incomplete = selectedSchedule.filter { !$0.block.completedDates.contains($0.dateKey) }
        return incomplete.first(where: { $0.start <= now && now < $0.end })
            ?? incomplete.first(where: { $0.start > now })
            ?? incomplete.first
            ?? selectedSchedule.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateCard
                    if let focus {
                        focusCard(focus)
                        actionsCard(focus)
                    } else {
                        ContentUnavailableView(
                            "No blocks yet",
                            systemImage: "calendar.badge.plus",
                            description: Text("Create your first focus block in Blocks.")
                        )
                        .frame(minHeight: 260)
                    }
                    dayList
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Project I")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onReceive(timer) { now = $0 }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CURRENT DATE")
                .font(.caption2.bold())
                .tracking(1.4)
                .foregroundStyle(AppTheme.muted)
            HStack {
                Button { moveDay(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text(DateTools.displayDate(store.selectedDate))
                        .font(.headline)
                    if !isToday {
                        Button("Return to today") { store.selectDate(Date()) }
                            .font(.caption)
                    }
                }
                Spacer()
                Button { moveDay(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
            }
        }
        .padding(18)
        .istiqamahCard()
    }

    private func focusCard(_ item: ScheduledBlock) -> some View {
        let phase = phase(for: item)
        let completed = item.block.completedDates.contains(item.dateKey)
        let remaining = phase == .upcoming ? item.start.timeIntervalSince(now) : item.end.timeIntervalSince(now)
        let duration = max(1, item.end.timeIntervalSince(item.start))
        let progress = phase == .running ? max(0, min(1, now.timeIntervalSince(item.start) / duration)) : phase == .ended ? 1 : 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(phase.label)
                    .font(.caption2.bold())
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                Image(systemName: phase == .running ? "flame.fill" : "timer")
                    .foregroundStyle(phase == .running ? AppTheme.flame : AppTheme.primary)
                    .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.7))
            }
            Text(item.block.name)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
            Text(DateTools.clock(seconds: remaining))
                .font(.system(size: 46, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
            ProgressView(value: progress)
                .tint(AppTheme.primary)
            HStack {
                Text("\(item.block.startTime) – \(item.block.endTime)")
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Button(completed ? "Completed" : "Mark complete") {
                    store.toggleBlock(item.block.id, dateKey: item.dateKey)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .disabled(now < item.start && !completed)
            }
            .font(.caption)
        }
        .padding(20)
        .istiqamahCard()
    }

    @ViewBuilder
    private func actionsCard(_ item: ScheduledBlock) -> some View {
        if !item.block.actions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIONS")
                    .font(.caption2.bold())
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.muted)
                    .padding(.bottom, 8)
                ForEach(item.block.actions) { action in
                    let completed = action.completedDates.contains(item.dateKey)
                    Button {
                        store.toggleAction(action.id, in: item.block.id, dateKey: item.dateKey)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(completed ? AppTheme.primary : AppTheme.muted)
                            Text(action.name)
                                .strikethrough(completed)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(now < item.start && !completed)
                }
            }
            .padding(18)
            .istiqamahCard()
        }
    }

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isToday ? "TODAY'S SYSTEM" : "SELECTED DAY'S SYSTEM")
                .font(.caption2.bold())
                .tracking(1.4)
                .foregroundStyle(AppTheme.muted)
            ForEach(selectedSchedule) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.block.completedDates.contains(item.dateKey) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(AppTheme.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.block.name).font(.subheadline.weight(.medium))
                        Text("\(item.block.startTime) – \(item.block.endTime)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .istiqamahCard()
    }

    private func moveDay(_ amount: Int) {
        let date = Calendar.current.date(byAdding: .day, value: amount, to: store.selectedDate) ?? store.selectedDate
        store.selectDate(date)
    }

    private func phase(for item: ScheduledBlock) -> BlockPhase {
        if now < item.start { return .upcoming }
        if now < item.end { return .running }
        return .ended
    }
}

private enum BlockPhase {
    case upcoming
    case running
    case ended

    var label: String {
        switch self {
        case .upcoming: "NEXT BLOCK"
        case .running: "RUNNING BLOCK"
        case .ended: "BLOCK ENDED"
        }
    }
}
