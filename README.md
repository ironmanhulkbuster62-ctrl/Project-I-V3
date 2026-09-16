# Project Istiqamah

Project Istiqamah is a private, local-first time-blocking and consistency app
built natively for iPhone with SwiftUI. It helps you define intentional blocks,
break them into small actions, record completion, and review consistency.

The native application lives in [`artifacts/project-istiqamah`](artifacts/project-istiqamah).

## Native iOS architecture

- SwiftUI application and navigation
- ActivityKit and WidgetKit Live Activity extension
- BackgroundTasks refresh for best-effort system wakeups
- Codable JSON persistence in Application Support
- UserNotifications reminders, start alerts, and completion alerts
- Charts-based seven-day progress dashboard
- XcodeGen project definition committed as `project.json`
- No Expo, React Native, JavaScript bundle, CocoaPods, account, or backend

## What works now

| Area | Implemented behavior |
| --- | --- |
| App navigation | Native SwiftUI tabs for Today, Blocks, Progress, and Settings |
| Block planning | Create, edit, and delete blocks with a name, note, validated 24-hour start/end times, overnight ranges, and up to five checklist actions |
| Daily view | Previous/next-day navigation, return to today, automatic selection of the running or next block, a one-second countdown, and progress through the active block |
| Completion | Mark blocks and individual actions complete after their start time; completion is stored separately for each date |
| Progress | Seven-day chart, completed-block total, practiced-day count, consistency percentage, current streak, and per-block completion totals |
| Reminders | Time-sensitive alerts before a block, when it starts, and when it ends; the early reminder is configurable to 5, 10, or 15 minutes |
| Reminder sounds | System Default, Gentle Chime, Bright Bell, and Focus Pulse choices, plus a two-second in-app test reminder |
| Live Activities | Starts or updates the current block, removes completed or outdated activities, schedules upcoming starts on iOS 26, and provides status, refresh, and restart controls in Settings |
| Background refresh | Reloads saved blocks during system-granted background time, refreshes notifications and Live Activities, and schedules the next best-effort wakeup near a block transition |
| Dynamic Island | Compact real-time countdown capsule, expanded remaining-time region on the left, running block in the center, layered glowing native flame on the right, and an Open app link |
| Lock Screen | Block name, schedule, live countdown, completion prompt after the block ends, and tap-to-open behavior |
| Deep links | Notification and Live Activity taps open the Today tab on the relevant date and block; an ended-block link can record completion |
| Local data | Codable JSON persistence in Application Support, preservation of an unreadable data file for recovery, and exclusion of private app data from device/iCloud backup |
| Preferences | Reminder toggle, reminder timing, sound choice, haptic toggle, notification permission status, and shortcut to iOS Settings |
| Backup | Pretty-printed JSON export through the native share sheet |
| CI package | Manual or version-tag GitHub Action builds the app and embedded Live Activity extension into an unsigned IPA |

The code and project configuration for these behaviors are present. The JSON
project definition, property lists, embedded widget target, sound resources,
and unsigned-IPA workflow can be checked without launching the app. A complete
runtime check of notifications, Lock Screen presentation, and Dynamic Island
presentation requires a signed build on a physical iPhone with notification
and Live Activity permissions enabled.

## Build requirements

- macOS with Xcode 26 or later
- XcodeGen
- iOS 18 or later deployment target

Generate the Xcode project:

```bash
cd artifacts/project-istiqamah
xcodegen generate --spec project.json
open ProjectIstiqamah.xcodeproj
```

Choose an Apple development team in Xcode, then run the `ProjectIstiqamah`
scheme on an iPhone. Live Activities require a physical supported device for
complete Dynamic Island testing.

## Unsigned IPA

The GitHub workflow in `.github/workflows/build-ios-ipa.yml` generates the
Xcode project, builds the native app and widget extension, and publishes an
unsigned IPA artifact. See [`docs/github-actions-ios.md`](docs/github-actions-ios.md).

## Repository structure

| Path | Purpose |
| --- | --- |
| `artifacts/project-istiqamah/Sources/App` | SwiftUI app, persistence, notifications, and ActivityKit lifecycle |
| `artifacts/project-istiqamah/Sources/Shared` | Activity attributes shared with the widget extension |
| `artifacts/project-istiqamah/Sources/Widgets` | Native WidgetKit and Dynamic Island UI |
| `artifacts/project-istiqamah/Config` | Generated app and extension property-list paths |
| `artifacts/project-istiqamah/Resources/Sounds` | Bundled Linear PCM reminder sounds |
| `artifacts/project-istiqamah/project.json` | XcodeGen project source of truth |

## Current limitations and next work

- Existing Expo AsyncStorage data is not automatically migrated; export it
  before installing the native rewrite if it must be retained.
- Scheduled Live Activity starts require iOS 26. On iOS 18–25, the current
  block starts its Live Activity whenever the app is active and notifications
  remain the background fallback.
- iOS does not allow this app to run continuously. Background App Refresh is
  system-controlled and may run later than requested or not run at all, so it
  cannot guarantee an exact Live Activity start.
- Immediate WhatsApp-style remote updates require an APNs provider and backend.
  This local-first app has no account or server, so it does not register or
  upload push tokens.
- Dynamic Island is available only on supported iPhone models. The flame is an
  animated native SF Symbol, not a bundled GIF.
- An unsigned IPA must be signed before it can be installed on an iPhone.
- The app exports backups but does not import them yet.
- Repeat schedules, weekday selection, snooze, templates, tags, search, and
  archives are not implemented.
- Screen Time integration still requires Apple's Family Controls entitlement.
- Accessibility and localization need a complete device audit.
- Native unit, UI, and snapshot tests remain to be added.

## Data and privacy

Task content and preferences stay in the app's Application Support directory,
which is excluded from device and iCloud backups. Data leaves the device only
when the user explicitly shares an exported backup.

## License

MIT
