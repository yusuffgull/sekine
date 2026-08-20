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
    static func handle(settings: AppSettings) async {
        await WatchNotificationScheduler.reschedule(settings: settings)
        schedule()
    }
}
