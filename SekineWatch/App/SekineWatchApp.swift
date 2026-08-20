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
            await WatchBackgroundRefresh.handle(settings: settings)
        }
    }

    private func bootstrap() async {
        watchSession.configure(settings: settings)
        _ = await notifications.requestAuthorization()
        if let loc = settings.location {
            await store.ensureData(for: loc, settings: settings)
            await WatchNotificationScheduler.reschedule(settings: settings)
        }
    }
}
