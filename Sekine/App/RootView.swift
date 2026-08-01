import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding, settings.location != nil {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            MonthlyView()
                .tabItem { Label("Aylık", systemImage: "calendar") }
            QiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }
            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
    }
}
