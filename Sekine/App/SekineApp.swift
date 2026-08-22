import SwiftUI
import CoreLocation

@main
struct SekineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = AppSettings()
    @StateObject private var store = PrayerTimeStore()
    @StateObject private var notifications = NotificationManager()
    @StateObject private var location = LocationManager()
    @StateObject private var locationDirectory = DiyanetDirectory()
    @StateObject private var iap = Store()
    @StateObject private var adhan = AdhanPlayer()
    @StateObject private var watchSession = WatchSessionManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(notifications)
                .environmentObject(location)
                .environmentObject(iap)
                .environmentObject(adhan)
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
            settings.location = SavedLocation(name: "İstanbul", latitude: 41.0082,
                                              longitude: 28.9784, diyanetDistrictID: "9541")
            settings.hasCompletedOnboarding = true
        }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-uiTestFontScale"), i + 1 < args.count,
           let scale = FontScale(rawValue: args[i + 1]) {
            settings.fontScale = scale
        }
        if let i = args.firstIndex(of: "-uiTestColorTheme"), i + 1 < args.count,
           let theme = ColorTheme(rawValue: args[i + 1]) {
            settings.colorTheme = theme
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTestForceLocationCheck") {
            settings.lastLocationCheckAt = nil
        }
        #endif
        await notifications.refreshStatus()
        if let loc = settings.location {
            await store.ensureData(for: loc, settings: settings)
            await checkForLocationDrift(currentLocation: loc)
        }
        watchSession.configure(settings: settings, iap: iap)
    }

    /// Kullanıcı seyahat ettiyse (ör. İstanbul → Sakarya) konumun sessizce
    /// bayatlamasını önler: günde en fazla bir kez, GPS'i tekrar okuyup Diyanet
    /// ilçesi değiştiyse `pendingLocationSuggestion`'a yazar (UI onay ister,
    /// otomatik değiştirmez). Yeni izin istemez — onboarding'de zaten alınmıştır.
    private func checkForLocationDrift(currentLocation: SavedLocation) async {
        guard location.authorizationStatus == .authorizedWhenInUse
                || location.authorizationStatus == .authorizedAlways else { return }
        if let last = settings.lastLocationCheckAt, Date().timeIntervalSince(last) < 86_400 { return }
        settings.lastLocationCheckAt = Date()

        guard let result = try? await location.resolveAndMatchDiyanetLocation(directory: locationDirectory),
              result.matched, result.location.diyanetDistrictID != currentLocation.diyanetDistrictID,
              result.location.diyanetDistrictID != settings.declinedLocationDistrictID
        else { return }
        settings.pendingLocationSuggestion = result.location
    }
}
