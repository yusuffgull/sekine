import Foundation
import WatchConnectivity
import Combine

/// iPhone tarafı: watch app'in ilk kurulumunu hızlandırmak için konum/tema/premium
/// ipucunu Watch'a aktarır. Bu bir KONFOR katmanı DEĞİL — konumun iki cihazda aynı
/// kalması, RollingScheduler'ın deterministik bildirim kimliklerinin eşleşmesini (dolayısıyla
/// çift bildirim olmamasını) sağlıyor. Yine de zorunlu bağımlılık değildir: watch, hiç
/// eşleşmemişse kendi onboarding'iyle bağımsız çalışmaya devam eder.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    private var cancellables: Set<AnyCancellable> = []

    func configure(settings: AppSettings, iap: Store) {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()

        settings.objectWillChange
            .merge(with: iap.objectWillChange)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self, weak settings, weak iap] _ in
                guard let settings, let iap else { return }
                self?.sync(settings: settings, iap: iap)
            }
            .store(in: &cancellables)

        sync(settings: settings, iap: iap)
    }

    private func sync(settings: AppSettings, iap: Store) {
        guard WCSession.default.activationState == .activated else { return }
        var context: [String: Any] = [
            "isPremium": iap.isPremium,
            "colorTheme": settings.colorTheme.rawValue
        ]
        if let location = settings.location {
            context["locationName"] = location.name
            context["latitude"] = location.latitude
            context["longitude"] = location.longitude
            if let districtID = location.diyanetDistrictID {
                context["diyanetDistrictID"] = districtID
            }
        }
        try? WCSession.default.updateApplicationContext(context)
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
