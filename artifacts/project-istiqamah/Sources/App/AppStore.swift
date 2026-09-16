import Combine
import Foundation
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var blocks: [FocusBlock]
    @Published var preferences: AppPreferences
    @Published var selectedDate = Date()
    @Published private(set) var requestedBlockID: UUID?
    @Published private(set) var liveActivityStatus = "Checking…"
    @Published private(set) var notificationTestStatus: String?

    private let storageURL: URL
    private var refreshGeneration = 0

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("ProjectIstiqamah", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? (directory as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        storageURL = directory.appendingPathComponent("data.json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let needsInitialPersist: Bool
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                let snapshot = try decoder.decode(AppSnapshot.self, from: data)
                blocks = snapshot.blocks
                preferences = snapshot.preferences
                needsInitialPersist = false
            } catch {
                blocks = Self.seedBlocks
                preferences = AppPreferences()
                let unreadableURL = directory
                    .appendingPathComponent("data-unreadable-\(UUID().uuidString).json")
                needsInitialPersist = (try? FileManager.default.moveItem(
                    at: storageURL,
                    to: unreadableURL
                )) != nil
            }
        } else {
            blocks = Self.seedBlocks
            preferences = AppPreferences()
            needsInitialPersist = true
        }
        requestedBlockID = nil
        if needsInitialPersist {
            persist()
        }
    }

    func add(_ block: FocusBlock) {
        blocks.append(block)
        changed()
    }

    func update(_ block: FocusBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        blocks[index] = block
        changed()
    }

    func remove(_ block: FocusBlock) {
        blocks.removeAll { $0.id == block.id }
        changed()
    }

    func toggleBlock(_ blockID: UUID, dateKey: String) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        if blocks[index].completedDates.contains(dateKey) {
            blocks[index].completedDates.remove(dateKey)
        } else {
            guard canRecordCompletion(for: blocks[index], dateKey: dateKey) else { return }
            blocks[index].completedDates.insert(dateKey)
            haptic(.success)
        }
        changed()
    }

    func toggleAction(_ actionID: UUID, in blockID: UUID, dateKey: String) {
        guard let blockIndex = blocks.firstIndex(where: { $0.id == blockID }),
              let actionIndex = blocks[blockIndex].actions.firstIndex(where: { $0.id == actionID }) else { return }
        if blocks[blockIndex].actions[actionIndex].completedDates.contains(dateKey) {
            blocks[blockIndex].actions[actionIndex].completedDates.remove(dateKey)
        } else {
            guard canRecordCompletion(for: blocks[blockIndex], dateKey: dateKey) else { return }
            blocks[blockIndex].actions[actionIndex].completedDates.insert(dateKey)
            haptic(.light)
        }
        changed()
    }

    func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        update(&preferences)
        preferences.reminderMinutes = min(15, max(5, preferences.reminderMinutes))
        changed()
    }

    func selectDate(_ date: Date) {
        requestedBlockID = nil
        selectedDate = date
    }

    func handle(_ route: AppRoute) {
        guard let blockID = route.blockID,
              let dateKey = route.dateKey,
              blocks.contains(where: { $0.id == blockID }) else { return }
        if let date = DateTools.date(from: dateKey) {
            selectedDate = date
        }
        requestedBlockID = blockID
        if route.action == "complete",
           let block = blocks.first(where: { $0.id == blockID }),
           let date = DateTools.date(from: dateKey),
           let window = DateTools.window(for: block, on: date),
           Date() >= window.end,
           !block.completedDates.contains(dateKey) {
            toggleBlock(blockID, dateKey: dateKey)
        }
    }

    func exportBackup() throws -> URL {
        let snapshot = AppSnapshot(version: 2, exportedAt: Date(), blocks: blocks, preferences: preferences)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Project-Istiqamah-Backup.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func refreshSystemFeatures() {
        let currentBlocks = blocks
        let currentPreferences = preferences
        BackgroundRefreshManager.shared.schedule(blocks: currentBlocks)
        refreshGeneration &+= 1
        let generation = refreshGeneration
        Task { [weak self] in
            async let notificationSync: Void = NotificationManager.shared.sync(
                blocks: currentBlocks,
                preferences: currentPreferences
            )
            async let activitySync = LiveActivityManager.shared.sync(blocks: currentBlocks)
            let report = await activitySync
            if let self, let report, generation == self.refreshGeneration {
                self.liveActivityStatus = report.message
            }
            _ = await notificationSync
        }
    }

    func restartLiveActivity() {
        let currentBlocks = blocks
        liveActivityStatus = "Restarting…"
        refreshGeneration &+= 1
        let generation = refreshGeneration
        Task { [weak self] in
            let report = await LiveActivityManager.shared.restart(blocks: currentBlocks)
            guard let self, let report, generation == self.refreshGeneration else { return }
            self.liveActivityStatus = report.message
        }
    }

    func sendTestReminder() {
        let currentPreferences = preferences
        notificationTestStatus = "Scheduling…"
        Task { [weak self] in
            let message = await NotificationManager.shared.sendTest(preferences: currentPreferences)
            self?.notificationTestStatus = message
        }
    }

    private func changed() {
        persist()
        refreshSystemFeatures()
    }

    private func canRecordCompletion(for block: FocusBlock, dateKey: String) -> Bool {
        guard let date = DateTools.date(from: dateKey),
              let window = DateTools.window(for: block, on: date) else {
            return false
        }
        return Date() >= window.start
    }

    private func persist() {
        let snapshot = AppSnapshot(version: 2, exportedAt: Date(), blocks: blocks, preferences: preferences)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func haptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        guard preferences.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(style)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard preferences.haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static let seedBlocks: [FocusBlock] = [
        FocusBlock(
            name: "Fajr Block",
            startTime: "05:00",
            endTime: "06:30",
            note: "Start the day before the noise.",
            actions: [BlockAction(name: "Pray Fajr"), BlockAction(name: "Read Quran")]
        ),
        FocusBlock(
            name: "Work Hours Discipline",
            startTime: "09:00",
            endTime: "17:00",
            note: "Stay focused. Follow the plan."
        ),
        FocusBlock(
            name: "Evening Block",
            startTime: "19:30",
            endTime: "20:30",
            note: "Close the day with intention."
        ),
        FocusBlock(
            name: "Night Block",
            startTime: "21:30",
            endTime: "22:30",
            note: "Prepare tomorrow before sleep."
        )
    ]
}
