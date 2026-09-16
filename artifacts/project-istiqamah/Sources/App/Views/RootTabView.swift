import Combine
import SwiftUI

private enum AppTab: Hashable {
    case today
    case blocks
    case progress
    case settings
}

struct RootTabView: View {
    @State private var selection: AppTab = .today
    @StateObject private var router = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("Today", systemImage: "house") }
                .tag(AppTab.today)

            BlocksView()
                .tabItem { Label("Blocks", systemImage: "checkmark.square") }
                .tag(AppTab.blocks)

            ProgressDashboard()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
                .tag(AppTab.progress)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(AppTheme.primary)
        .onReceive(router.$route.compactMap { $0 }) { _ in
            selection = .today
        }
    }
}
