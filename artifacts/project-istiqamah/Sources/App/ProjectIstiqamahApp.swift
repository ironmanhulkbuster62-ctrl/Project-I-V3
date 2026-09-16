import Combine
import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BackgroundRefreshManager.shared.register()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let data = response.notification.request.content.userInfo
        let blockID = (data["blockID"] as? String).flatMap(UUID.init(uuidString:))
        let dateKey = data["date"] as? String
        let action = data["action"] as? String
        Task { @MainActor in
            DeepLinkRouter.shared.open(blockID: blockID, dateKey: dateKey, action: action)
            completionHandler()
        }
    }
}

@main
struct ProjectIstiqamahApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @StateObject private var router = DeepLinkRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .onOpenURL { router.open($0) }
                .onReceive(router.$route.compactMap { $0 }) { route in
                    store.handle(route)
                }
                .task {
                    store.refreshSystemFeatures()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshSystemFeatures()
            }
        }
    }
}
