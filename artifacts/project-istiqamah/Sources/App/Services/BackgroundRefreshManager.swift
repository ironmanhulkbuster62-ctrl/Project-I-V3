import BackgroundTasks
import Foundation

final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    static let taskIdentifier = "com.projectistiqamah.app.refresh"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    func schedule(blocks: [FocusBlock], now: Date = Date()) {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = nextRefreshDate(blocks: blocks, now: now)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // The system may reject requests when Background App Refresh is disabled.
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        let work = Task {
            do {
                let snapshot = try loadSnapshot()
                schedule(blocks: snapshot.blocks)

                async let notificationSync: Void = NotificationManager.shared.sync(
                    blocks: snapshot.blocks,
                    preferences: snapshot.preferences
                )
                async let activitySync = LiveActivityManager.shared.sync(blocks: snapshot.blocks)
                _ = await activitySync
                _ = await notificationSync
                task.setTaskCompleted(success: !Task.isCancelled)
            } catch {
                schedule(blocks: [])
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            work.cancel()
        }
    }

    private func nextRefreshDate(blocks: [FocusBlock], now: Date) -> Date {
        let minimumDate = now.addingTimeInterval(1)
        let candidates = DateTools.schedule(for: blocks, around: now)
            .flatMap { item in
                let startWake = item.start > minimumDate
                    ? max(item.start.addingTimeInterval(-2 * 60), minimumDate)
                    : nil
                return [startWake, item.end].compactMap { $0 }
            }
            .filter { $0 >= minimumDate }

        return candidates.min() ?? now.addingTimeInterval(6 * 60 * 60)
    }

    private func loadSnapshot() throws -> AppSnapshot {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let url = support
            .appendingPathComponent("ProjectIstiqamah", isDirectory: true)
            .appendingPathComponent("data.json")
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppSnapshot.self, from: data)
    }
}
