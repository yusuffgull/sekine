import SwiftUI

@main
struct SekineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = AppSettings()
    @StateObject private var store = PrayerTimeStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var location = LocationManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(notifications)
                .environmentObject(location)
                .tint(Palette.accent)
                .preferredColorScheme(settings.theme.colorScheme)
                .task { await bootstrap() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await bootstrap() }
                BackgroundRefresh.schedule()
            }
        }
    }

    /// App açılışında/öne gelince: izin durumunu tazele, veri varsa kapsamı
    /// kontrol et ve bildirimleri yeniden zamanla.
    private func bootstrap() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedIstanbul"),
           settings.location == nil {
            settings.location = SavedLocation(name: "İstanbul", latitude: 41.0082, longitude: 28.9784)
            settings.hasCompletedOnboarding = true
        }
        #endif
        await notifications.refreshStatus()
        if let loc = settings.location {
            await store.ensureData(for: loc, settings: settings)
        }
    }
}
