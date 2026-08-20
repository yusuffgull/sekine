import SwiftUI

@main
struct SekineWatchApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = PrayerTimeStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var location = LocationManager()
    @StateObject private var iap = Store()
    @StateObject private var watchSession = WatchSessionManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(notifications)
                .environmentObject(location)
                .environmentObject(iap)
                .task { await bootstrap() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await bootstrap() }
                WatchBackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(WatchBackgroundRefresh.refreshTaskID)) {
            await WatchBackgroundRefresh.handle(store: store, settings: settings)
        }
    }

    private func bootstrap() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedIstanbul"),
           settings.location == nil {
            settings.location = SavedLocation(name: "İstanbul", latitude: 41.0082,
                                              longitude: 28.9784, diyanetDistrictID: "9541")
            settings.hasCompletedOnboarding = true
        }
        #endif
        settings.disableCrossDeviceExtraNotifications()
        watchSession.configure(settings: settings, store: store)
        // İzin isteme burada DEĞİL — yalnızca onboarding'i bitirirken bir kez istenir
        // (bkz. WatchOnboardingView.finish), iOS'taki OnboardingView.finish() ile aynı desen.
        await notifications.refreshStatus()
        if let loc = settings.location {
            await store.ensureData(for: loc, settings: settings)
        }
    }
}
