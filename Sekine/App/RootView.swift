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
        // Yazı boyutu ayarı tüm ekranları (varsayılan fontlar dahil) etkiler.
        .dynamicTypeSize(settings.fontScale.dynamicTypeSize)
    }
}

struct MainTabView: View {
    @State private var selection: String = MainTabView.initialTab

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }.tag("home")
            MonthlyView()
                .tabItem { Label("Aylık", systemImage: "calendar") }.tag("monthly")
            QiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }.tag("qibla")
            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }.tag("settings")
        }
    }

    /// DEBUG'da ekran görüntüsü otomasyonu için başlangıç sekmesi seçilebilir.
    static var initialTab: String {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-uiTestTab"), i + 1 < args.count {
            return args[i + 1]
        }
        #endif
        return "home"
    }
}
