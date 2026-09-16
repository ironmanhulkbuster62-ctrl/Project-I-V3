import Charts
import SwiftUI

private struct DayTotal: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

struct ProgressDashboard: View {
    @EnvironmentObject private var store: AppStore

    private var history: [DayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let key = DateTools.key(date)
            return DayTotal(
                date: date,
                count: store.blocks.filter { $0.completedDates.contains(key) }.count
            )
        }
    }

    private var completedLastSevenDays: Int {
        history.reduce(0) { $0 + $1.count }
    }

    private var practicedDays: Int {
        history.filter { $0.count > 0 }.count
    }

    private var consistency: Int {
        guard !store.blocks.isEmpty else { return 0 }
        return Int((Double(completedLastSevenDays) / Double(store.blocks.count * 7) * 100).rounded())
    }

    private var streak: Int {
        let completed = Set(store.blocks.flatMap(\.completedDates))
        var value = 0
        var date = Date()
        while completed.contains(DateTools.key(date)) {
            value += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT STREAK")
                                .font(.caption2.bold())
                                .tracking(1.4)
                                .foregroundStyle(AppTheme.muted)
                            Text("\(streak)")
                                .font(.system(size: 62, weight: .regular))
                            Text(streak == 1 ? "DAY" : "DAYS")
                                .font(.caption.bold())
                        }
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(AppTheme.raised)
                            .clipShape(Circle())
                    }
                    .padding(20)
                    .istiqamahCard()

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Daily consistency").font(.headline)
                                Text("Completed blocks · last 7 days")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Text("\(completedLastSevenDays) TOTAL")
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.primary)
                        }
                        Chart(history) { day in
                            BarMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Completed", day.count)
                            )
                            .foregroundStyle(AppTheme.primary.gradient)
                            .cornerRadius(5)
                        }
                        .chartYScale(domain: 0...max(1, store.blocks.count))
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                            }
                        }
                        .frame(height: 190)
                    }
                    .padding(18)
                    .istiqamahCard()

                    HStack {
                        stat("DAYS PRACTICED", value: "\(practicedDays)")
                        stat("BLOCKS DONE", value: "\(completedLastSevenDays)")
                        stat("CONSISTENCY", value: "\(consistency)%")
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("YOUR REPEATERS")
                            .font(.caption2.bold())
                            .tracking(1.4)
                            .foregroundStyle(AppTheme.muted)
                        ForEach(store.blocks.sorted { $0.completedDates.count > $1.completedDates.count }) { block in
                            HStack {
                                Circle().fill(AppTheme.primary).frame(width: 7, height: 7)
                                Text(block.name).lineLimit(1)
                                Spacer()
                                Text("\(block.completedDates.count) days")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                    }
                    .padding(18)
                    .istiqamahCard()
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AppTheme.muted)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
