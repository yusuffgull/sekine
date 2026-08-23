import Foundation
import WatchConnectivity

/// Watch tarafı: iPhone'dan gelen konum/tema/premium ipucunu uygular. `isPremium`
/// yalnızca UI gecikmesini gizleyen bir ipucudur — nihai premium kararı her zaman
/// watch'ın kendi `Store.refreshEntitlements()` sonucudur (bkz. Store.swift).
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    private weak var settings: AppSettings?
    private weak var store: PrayerTimeStore?

    func configure(settings: AppSettings, store: PrayerTimeStore) {
        self.settings = settings
        self.store = store
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func apply(_ context: [String: Any]) {
        guard let settings else { return }
        if let raw = context["colorTheme"] as? String, let theme = ColorTheme(rawValue: raw) {
            settings.colorTheme = theme
        }
        // Koordinat opsiyonel: iPhone tarafında geocode başarısızsa hiç gönderilmez,
        // ama ilçe ID'si ile vakitler yine de doğru gelir.
        if let name = context["locationName"] as? String {
            let districtID = context["diyanetDistrictID"] as? String
            let incoming = SavedLocation(name: name,
                                         latitude: context["latitude"] as? Double,
                                         longitude: context["longitude"] as? Double,
                                         diyanetDistrictID: districtID)
            let locationChanged = settings.location?.diyanetDistrictID != incoming.diyanetDistrictID
                || settings.location?.name != incoming.name
            settings.location = incoming
            settings.hasCompletedOnboarding = true
            if locationChanged, let store {
                // Yeni konum için gerçek veri çeker; PrayerTimeStore kendi içinde
                // (extras zaten disableCrossDeviceExtraNotifications ile kapalı) bildirimleri
                // de yeniden zamanlar.
                Task { await store.ensureData(for: incoming, settings: settings) }
            }
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}
