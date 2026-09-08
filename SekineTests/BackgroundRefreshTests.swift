import XCTest
import UserNotifications
@testable import Sekine

/// VISION P2 turu: composition root'ta enjeksiyon başarısız olup `BackgroundRefresh.scheduler`
/// `nil` kaldığında (`register(scheduler:)` hiç çağrılmamışsa), `rescheduleFromCache` sessizce
/// "başarı" (`failed: 0, deferred: 0` → `isFullSuccess == true`) raporluyordu — bu, OS'a
/// yanlışlıkla başarı bildirip BGTask'in kendi retry/backoff mekanizmasını devre dışı
/// bırakabilirdi. Fix: scheduler nil iken `failed: 1` dönülür (`isFullSuccess == false`).
final class BackgroundRefreshTests: XCTestCase {

    override func tearDown() {
        // Bu test dosyası dışındaki testler/gerçek uygulama akışı `BackgroundRefresh.scheduler`'ı
        // kendi register(scheduler:) çağrısıyla ayarlar; burada nil'e set ettiğimiz için diğer
        // testleri etkilememek adına eski haline (nil) döndürmek yeterli — gerçek registration
        // yalnızca `AppDelegate` içinde, gerçek uygulama çalışırken olur, test hedefinde hiç
        // tetiklenmez.
        BackgroundRefresh.scheduler = nil
        super.tearDown()
    }

    func testRescheduleFromCacheReportsFailureWhenSchedulerNotInjected() async {
        // Composition root'ta enjeksiyon hiç yapılmamış senaryosu: `register(scheduler:)`
        // çağrılmamış, `scheduler` hâlâ `nil`.
        BackgroundRefresh.scheduler = nil

        let result = await BackgroundRefresh.rescheduleFromCache()

        XCTAssertFalse(
            result.isFullSuccess,
            "scheduler enjekte edilmemişken isFullSuccess YANLIŞLIKLA true olmamalı — " +
            "OS'a sahte bir başarı raporlanmamalı")
        XCTAssertGreaterThan(result.failed, 0, "scheduler-yok durumu açıkça bir başarısızlık olarak sayılmalı")
        XCTAssertEqual(result.requested, 0)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.deferred, 0)
    }

    func testRescheduleFromCacheSucceedsOnceSchedulerIsInjected() async {
        // Karşılaştırma: scheduler enjekte edilince (ve cache boşken) hâlâ makul/başarılı
        // bir "yapacak iş yok" sonucu dönmeli — bu test yalnızca nil-scheduler durumunun
        // ÖZEL olarak başarısızlık saydığını, cache-boş durumunun genel olarak
        // "başarısızlık" sayılmadığını netleştirir (regresyon önleyici).
        let mock = NoOpNotificationCenterForBackgroundRefreshTests()
        BackgroundRefresh.scheduler = RollingScheduler(center: mock)

        let result = await BackgroundRefresh.rescheduleFromCache()

        // Cache muhtemelen bu test ortamında boş/yok — o durumda da isFullSuccess true
        // olmalı (nil-scheduler durumundan FARKLI olarak, gerçek bir hata değil).
        XCTAssertTrue(result.isFullSuccess)
    }
}

/// Yalnızca `BackgroundRefreshTests`'te scheduler'ı gerçek bir `RollingScheduler` ile
/// enjekte edebilmek için minimal, hiçbir şey yapmayan sahte bildirim merkezi.
private final class NoOpNotificationCenterForBackgroundRefreshTests: NotificationScheduling, @unchecked Sendable {
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func add(_ request: UNNotificationRequest) async throws {}
}
