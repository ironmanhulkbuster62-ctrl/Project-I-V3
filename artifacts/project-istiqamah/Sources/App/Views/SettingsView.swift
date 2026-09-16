import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    @State private var backupURL: URL?
    @State private var backupError: String?
    @State private var notificationStatus = "Checking…"
    @State private var backgroundRefreshStatus = "Checking…"

    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Haptic feedback", isOn: preferenceBinding(\.haptics))
                    Toggle("Block reminders", isOn: preferenceBinding(\.reminders))
                    Stepper(
                        "Remind me \(store.preferences.reminderMinutes) minutes early",
                        value: reminderBinding,
                        in: 5...15,
                        step: 5
                    )
                    Picker("Reminder sound", selection: reminderSoundBinding) {
                        ForEach(ReminderSound.allCases) { sound in
                            Text(sound.title).tag(sound)
                        }
                    }
                }

                Section("Live blocks") {
                    Label("Dynamic Island & Lock Screen", systemImage: "flame.fill")
                        .foregroundStyle(AppTheme.flame)
                    LabeledContent("Status", value: store.liveActivityStatus)
                    LabeledContent("Background refresh", value: backgroundRefreshStatus)
                    Text("ActivityKit schedules upcoming blocks on iOS 26 and starts the current block when the app is active on earlier supported versions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("iOS chooses when background refresh runs, so notifications remain the reliable fallback for exact block times.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Refresh Live Activities") {
                        store.refreshSystemFeatures()
                    }
                    Button("Restart current Live Activity") {
                        store.restartLiveActivity()
                    }
                }

                Section("Notifications") {
                    LabeledContent("Permission", value: notificationStatus)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Send test reminder", systemImage: "speaker.wave.2") {
                        store.sendTestReminder()
                    }
                    if let notificationTestStatus = store.notificationTestStatus {
                        Text(notificationTestStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Your data") {
                    Button("Prepare JSON backup", systemImage: "square.and.arrow.up") {
                        do {
                            backupURL = try store.exportBackup()
                            backupError = nil
                        } catch {
                            backupURL = nil
                            backupError = "Backup failed: \(error.localizedDescription)"
                        }
                    }
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Share backup", systemImage: "paperplane")
                        }
                    }
                    if let backupError {
                        Text(backupError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Data is stored privately in the app's Application Support directory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Project Istiqamah", value: "1.0.0")
                    Text("A private practice of showing up, one block at a time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Settings")
            .task {
                await loadNotificationStatus()
                loadBackgroundRefreshStatus()
            }
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { value in store.updatePreferences { $0[keyPath: keyPath] = value } }
        )
    }

    private var reminderBinding: Binding<Int> {
        Binding(
            get: { store.preferences.reminderMinutes },
            set: { value in store.updatePreferences { $0.reminderMinutes = value } }
        )
    }

    private var reminderSoundBinding: Binding<ReminderSound> {
        Binding(
            get: { store.preferences.reminderSound },
            set: { value in store.updatePreferences { $0.reminderSound = value } }
        )
    }

    private func loadNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = switch settings.authorizationStatus {
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .denied: "Denied"
        case .notDetermined: "Not requested"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }

    private func loadBackgroundRefreshStatus() {
        backgroundRefreshStatus = switch UIApplication.shared.backgroundRefreshStatus {
        case .available: "Available"
        case .denied: "Disabled"
        case .restricted: "Restricted"
        @unknown default: "Unknown"
        }
    }
}
