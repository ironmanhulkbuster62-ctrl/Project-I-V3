import ActivityKit
import Foundation

struct LiveActivityReport: Sendable {
    let message: String
}

actor LiveActivityManager {
    static let shared = LiveActivityManager()
    private var syncGeneration = 0
    private var activityMutationTail: Task<Void, Never>?

    func sync(blocks: [FocusBlock], now: Date = Date()) async -> LiveActivityReport? {
        syncGeneration &+= 1
        let generation = syncGeneration
        return await synchronize(blocks: blocks, now: now, generation: generation)
    }

    private func synchronize(
        blocks: [FocusBlock],
        now: Date,
        generation: Int
    ) async -> LiveActivityReport? {
        guard generation == syncGeneration else { return nil }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return LiveActivityReport(message: "Disabled in iOS Settings")
        }

        let active = DateTools.activeBlock(in: blocks, at: now)
        let currentSchedule = Dictionary(
            uniqueKeysWithValues: DateTools.schedule(for: blocks, around: now).map {
                ("\($0.block.id.uuidString):\($0.dateKey)", $0)
            }
        )
        for activity in Activity<BlockActivityAttributes>.activities {
            guard generation == syncGeneration else { return nil }
            let key = "\(activity.attributes.blockID.uuidString):\(activity.attributes.dateKey)"
            let scheduled = currentSchedule[key]
            let completed = scheduled?.block.completedDates.contains(activity.attributes.dateKey) ?? true
            let changed = scheduled.map {
                $0.block.name != activity.content.state.blockName ||
                $0.start != activity.content.state.startDate ||
                $0.end != activity.content.state.endDate
            } ?? true
            let tooOld = activity.content.state.endDate.addingTimeInterval(4 * 60 * 60) < now
            if completed || changed || tooOld {
                await performActivityMutation {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                guard generation == syncGeneration else { return nil }
            }
        }

        if let active {
            do {
                guard try await startIfNeeded(active, generation: generation) else { return nil }
            } catch {
                return LiveActivityReport(message: "Start failed: \(error.localizedDescription)")
            }
        }

        guard generation == syncGeneration else { return nil }
        var schedulingError: String?
        if #available(iOS 26.0, *) {
            schedulingError = scheduleUpcoming(blocks: blocks, now: now)
        }

        let activities = Activity<BlockActivityAttributes>.activities
        let hasCurrentActivity = active.map { active in
            activities.contains(where: {
               $0.attributes.blockID == active.block.id &&
               $0.attributes.dateKey == active.dateKey &&
               $0.activityState == .active
            })
        } ?? false
        if let schedulingError {
            if let active, hasCurrentActivity {
                return LiveActivityReport(
                    message: "Live now: \(active.block.name) · upcoming failed: \(schedulingError)"
                )
            }
            return LiveActivityReport(message: "Scheduling failed: \(schedulingError)")
        }
        if let active, hasCurrentActivity {
            return LiveActivityReport(message: "Live now: \(active.block.name)")
        }

        let pendingCount: Int
        if #available(iOS 26.0, *) {
            pendingCount = activities.filter { $0.activityState == .pending }.count
        } else {
            pendingCount = 0
        }
        if pendingCount > 0 {
            let label = pendingCount == 1 ? "activity" : "activities"
            return LiveActivityReport(message: "Ready · \(pendingCount) upcoming \(label)")
        }
        return LiveActivityReport(message: "Ready · no block is running")
    }

    func restart(blocks: [FocusBlock], now: Date = Date()) async -> LiveActivityReport? {
        syncGeneration &+= 1
        let generation = syncGeneration
        for activity in Activity<BlockActivityAttributes>.activities {
            guard generation == syncGeneration else { return nil }
            await performActivityMutation {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard generation == syncGeneration else { return nil }
        }
        return await synchronize(blocks: blocks, now: now, generation: generation)
    }

    private func startIfNeeded(_ item: ScheduledBlock, generation: Int) async throws -> Bool {
        guard generation == syncGeneration else { return false }
        let existing = Activity<BlockActivityAttributes>.activities.first {
            $0.attributes.blockID == item.block.id && $0.attributes.dateKey == item.dateKey
        }
        let content = activityContent(for: item)
        if let existing, existing.activityState == .active {
            await performActivityMutation {
                await existing.update(content)
            }
            return generation == syncGeneration
        }
        if let existing {
            await performActivityMutation {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            guard generation == syncGeneration else { return false }
        }
        guard generation == syncGeneration else { return false }
        _ = try Activity.request(
            attributes: attributes(for: item),
            content: content,
            pushType: nil
        )
        return generation == syncGeneration
    }

    private func performActivityMutation(
        _ operation: @escaping @Sendable () async -> Void
    ) async {
        let previous = activityMutationTail
        let task = Task {
            await previous?.value
            await operation()
        }
        activityMutationTail = task
        await task.value
    }

    @available(iOS 26.0, *)
    private func scheduleUpcoming(blocks: [FocusBlock], now: Date) -> String? {
        let activities = Activity<BlockActivityAttributes>.activities
        let existingKeys = Set(activities.map {
            "\($0.attributes.blockID.uuidString):\($0.attributes.dateKey)"
        })
        let occupiedSlots = activities.filter {
            $0.activityState == .active || $0.activityState == .pending
        }.count
        let availableSlots = max(0, 4 - occupiedSlots)
        let candidates = DateTools.schedule(for: blocks, around: now)
            .filter {
                $0.start > now.addingTimeInterval(30) &&
                !$0.block.completedDates.contains($0.dateKey) &&
                !existingKeys.contains("\($0.block.id.uuidString):\($0.dateKey)")
            }
            .prefix(availableSlots)

        for item in candidates {
            let alert = AlertConfiguration(
                title: "\(item.block.name) is starting",
                body: "Your focus block is now live.",
                sound: .default
            )
            do {
                _ = try Activity.request(
                    attributes: attributes(for: item),
                    content: activityContent(for: item, relevanceScore: 50),
                    pushType: nil,
                    style: .standard,
                    alertConfiguration: alert,
                    start: item.start
                )
            } catch {
                return error.localizedDescription
            }
        }
        return nil
    }

    private func attributes(for item: ScheduledBlock) -> BlockActivityAttributes {
        BlockActivityAttributes(blockID: item.block.id, dateKey: item.dateKey)
    }

    private func activityContent(
        for item: ScheduledBlock,
        relevanceScore: Double = 100
    ) -> ActivityContent<BlockActivityAttributes.ContentState> {
        ActivityContent(
            state: BlockActivityAttributes.ContentState(
                blockName: item.block.name,
                startDate: item.start,
                endDate: item.end,
                timeLabel: "\(item.block.startTime) – \(item.block.endTime)"
            ),
            staleDate: item.end,
            relevanceScore: relevanceScore
        )
    }
}
