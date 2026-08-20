import Foundation
import WatchKit

/// watchOS'ta BGTaskScheduler YOK; bunun yerine WKApplication'ın kendi arka plan
/// yenileme API'si kullanılır. Bütçe dar (dock'taki app başına ~saatte 1 görev,
/// çalışma başına ~4sn CPU/15sn toplam) — bu yüzden asıl güvenilirlik kaynağı
/// önceden planlanmış 60'lık bildirim penceresi; arka plan yenilemesi yalnızca
/// bu pencereyi tazeleyen bir ek katman.
enum WatchBackgroundRefresh {
    static let refreshTaskID = "com.sekineapp.sekine.watch.refresh"

    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 4 * 3600),
            userInfo: nil
        ) { _ in }
    }

    /// Cache + kayıtlı ayarlarla bildirimleri yeniden zamanlar (network yok).
    /// `store` üzerinden PrayerTimeStore'un kendi `rescheduleNotifications`'ı kullanılır —
    /// watch'ın extra bildirimleri (Cuma/kandil/ayet) zaten `AppSettings.forceDisableExtras()`
    /// ile kalıcı kapatıldığından (bkz. SekineWatchApp.bootstrap), ayrı bir config
    /// oluşturmaya gerek yok.
    @MainActor
    static func handle(store: PrayerTimeStore, settings: AppSettings) async {
        await store.rescheduleNotifications(settings: settings)
        schedule()
    }
}
