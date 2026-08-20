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
    var body: some View {
        TabView {
            WatchHomeView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            WatchQiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }
            WatchTesbihView()
                .tabItem { Label("Zikir", systemImage: "circle.grid.cross") }
        }
        .tabViewStyle(.page)
    }
}
