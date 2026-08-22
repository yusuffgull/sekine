import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var iap: Store

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding || settings.location == nil {
                WatchOnboardingView()
            } else if !iap.isPremium {
                WatchPaywallView()
            } else {
                WatchTabView()
            }
        }
    }
}

private struct WatchTabView: View {
    @State private var selection = "home"

    var body: some View {
        TabView(selection: $selection) {
            WatchHomeView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }
                .tag("home")
            WatchQiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }
                .tag("qibla")
            WatchTesbihView()
                .tabItem { Label("Zikir", systemImage: "circle.grid.cross") }
                .tag("spiritual")
        }
        .tabViewStyle(.page)
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-uiTestTab"), i + 1 < args.count {
                selection = args[i + 1]
            }
        }
        #endif
    }
}
