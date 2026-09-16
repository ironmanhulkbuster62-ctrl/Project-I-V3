import Foundation

struct BlockAction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var completedDates: Set<String> = []
}

struct FocusBlock: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var startTime: String
    var endTime: String
    var note: String
    var actions: [BlockAction] = []
    var completedDates: Set<String> = []
}

enum ReminderSound: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case gentleChime
    case brightBell
    case focusPulse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System Default"
        case .gentleChime: "Gentle Chime"
        case .brightBell: "Bright Bell"
        case .focusPulse: "Focus Pulse"
        }
    }

    var fileName: String? {
        switch self {
        case .system: nil
        case .gentleChime: "gentle-chime.wav"
        case .brightBell: "bright-bell.wav"
        case .focusPulse: "focus-pulse.wav"
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var haptics = true
    var reminders = true
    var reminderMinutes = 5
    var reminderSound: ReminderSound = .system

    private enum CodingKeys: String, CodingKey {
        case haptics
        case reminders
        case reminderMinutes
        case reminderSound
    }

    init(
        haptics: Bool = true,
        reminders: Bool = true,
        reminderMinutes: Int = 5,
        reminderSound: ReminderSound = .system
    ) {
        self.haptics = haptics
        self.reminders = reminders
        self.reminderMinutes = min(15, max(5, reminderMinutes))
        self.reminderSound = reminderSound
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        haptics = try values.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        reminders = try values.decodeIfPresent(Bool.self, forKey: .reminders) ?? true
        reminderMinutes = min(
            15,
            max(5, try values.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? 5)
        )
        reminderSound = try values.decodeIfPresent(ReminderSound.self, forKey: .reminderSound) ?? .system
    }
}

struct AppSnapshot: Codable {
    let version: Int
    let exportedAt: Date
    let blocks: [FocusBlock]
    let preferences: AppPreferences
}

struct ScheduledBlock: Identifiable {
    let block: FocusBlock
    let dateKey: String
    let start: Date
    let end: Date

    var id: String { "\(block.id.uuidString):\(dateKey)" }
}
