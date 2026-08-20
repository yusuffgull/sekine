import Foundation
import WatchConnectivity

/// Watch tarafı: iPhone'dan gelen konum/tema/premium ipucunu uygular. `isPremium`
/// yalnızca UI gecikmesini gizleyen bir ipucudur — nihai premium kararı her zaman
/// watch'ın kendi `Store.refreshEntitlements()` sonucudur (bkz. Store.swift).
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    private weak var settings: AppSettings?

    func configure(settings: AppSettings) {
        self.settings = settings
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func apply(_ context: [String: Any]) {
        guard let settings else { return }
        if let raw = context["colorTheme"] as? String, let theme = ColorTheme(rawValue: raw) {
            settings.colorTheme = theme
        }
        if let name = context["locationName"] as? String,
           let lat = context["latitude"] as? Double,
           let lng = context["longitude"] as? Double {
            let districtID = context["diyanetDistrictID"] as? String
            let incoming = SavedLocation(name: name, latitude: lat, longitude: lng, diyanetDistrictID: districtID)
            let locationChanged = settings.location?.diyanetDistrictID != incoming.diyanetDistrictID
                || settings.location?.latitude != incoming.latitude
            settings.location = incoming
            if locationChanged {
                Task { await WatchNotificationScheduler.reschedule(settings: settings) }
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
