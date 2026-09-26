import XCTest
import UserNotifications
@testable import Sekine

/// Sahte bildirim merkezi: gerçek `UNUserNotificationCenter` yerine `RollingScheduler`'a
/// enjekte edilir (bkz. `NotificationScheduling` protokolü). Pending/eklenen/kaldırılan
/// identifier'ları ve her `add()` çağrısının TAM içeriğini (fingerprint replace'i
/// doğrulamak için) izler.
///
/// `@unchecked Sendable`: yalnızca testlerde, tek bir `RollingScheduler` (actor, gerçek
/// FIFO + tek drain task ile serileştirilmiş) tarafından sırayla `await` edilerek
/// kullanılır — gerçek eş zamanlı erişim yok, bu yüzden manuel senkronizasyon eklemek
/// yerine bilinçli olarak `@unchecked` işaretlendi.
private final class MockNotificationCenter: NotificationScheduling, @unchecked Sendable {
    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var addCallCount = 0
    /// Her `add()` çağrısının SIRALI geçmişi — "aynı ID'ye ikinci add() farklı content'le
    /// mi çağrıldı" gibi replace testleri için.
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(pending.values)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        for id in identifiers { pending.removeValue(forKey: id) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
        addedRequests.append(request)
        pending[request.identifier] = request // UNUserNotificationCenter'ın kendi replace garantisi
    }

    /// Testin, gerçek bir cihazda zaten pending duran (bu scheduler'ın yaratmadığı ya da
    /// önceki bir turda yarattığı) kayıtları önceden yerleştirmesi için.
    func seed(_ requests: [UNNotificationRequest]) {
        for r in requests { pending[r.identifier] = r }
    }
}

/// Yalnızca kimlik + fingerprint taşıyan minimal sahte istek üretici (gerçek trigger/
/// içerik önemsiz olduğu testlerde — kapasite ve legacy-temizlik testlerinde kullanılır).
private func fakeRequest(identifier: String, fingerprint: String = "x") -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "t"
    content.userInfo = ["fingerprint": fingerprint]
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
    return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
}

final class RollingSchedulerTests: XCTestCase {

    private func makeSchedule(daysFromNow: [Int] = [1, 2, 3], fajrMinuteOffset: Int = 5 * 60) -> PrayerSchedule {
        let tz = TimeZone(identifier: "Europe/Istanbul")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = Date()

        let days: [PrayerDay] = daysFromNow.map { offset in
            let dayStart = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
            let times: [PrayerTime] = [
                PrayerTime(prayer: .fajr, date: cal.date(byAdding: .minute, value: fajrMinuteOffset, to: dayStart)!),
                PrayerTime(prayer: .dhuhr, date: cal.date(byAdding: .hour, value: 13, to: dayStart)!),
                PrayerTime(prayer: .asr, date: cal.date(byAdding: .hour, value: 16, to: dayStart)!),
                PrayerTime(prayer: .maghrib, date: cal.date(byAdding: .hour, value: 19, to: dayStart)!),
                PrayerTime(prayer: .isha, date: cal.date(byAdding: .hour, value: 21, to: dayStart)!)
            ]
            return PrayerDay(dayStart: dayStart, times: times)
        }
        return PrayerSchedule(placeName: "Test", latitude: nil, longitude: nil,
                               timeZoneIdentifier: tz.identifier, source: "local-adhan",
                               fetchedAt: now, days: days)
    }

    private func makeConfig(silent: Bool = false) -> SchedulerConfig {
        SchedulerConfig(
            enabledPrayers: Set(Prayer.ordered.filter(\.isNotifiable)),
            sound: .default,
            silent: silent,
            preReminderMinutes: 0,
            breakThroughFocus: false,
            fridayReminder: false,
            fridayReminderHour: 9,
            specialDayGreetings: false,
            dailyVerse: false,
            dailyVerseHour: 8
        )
    }

    // MARK: - İlk çalıştırma: hepsi eklenir

    func testFirstRescheduleAddsAllDesiredRequests() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule()
        let config = makeConfig()

        let result = await scheduler.reschedule(from: schedule, config: config)

        XCTAssertFalse(mock.pending.isEmpty)
        XCTAssertEqual(mock.addCallCount, mock.pending.count)
        XCTAssertTrue(mock.removedIdentifiers.isEmpty)
        XCTAssertTrue(result.isFullSuccess)
        XCTAssertEqual(result.deferred, 0)
    }

    // MARK: - Aynı config ile ikinci çağrı: zaten doğru olanlara dokunulmaz

    func testSecondRescheduleWithSameConfigTouchesNothing() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule()
        let config = makeConfig()

        await scheduler.reschedule(from: schedule, config: config)
        let countAfterFirst = mock.addCallCount

        await scheduler.reschedule(from: schedule, config: config)

        XCTAssertEqual(mock.addCallCount, countAfterFirst, "aynı ayarlarla ikinci çağrı yeni add() yapmamalı")
        XCTAssertTrue(mock.removedIdentifiers.isEmpty, "aynı ayarlarla hiçbir şey kaldırılmamalı")
    }

    // MARK: - (b) Aynı ID, farklı fingerprint → add() otomatik replace eder

    /// Stabil ID şemasında config değişince identifier AYNI kalır (tarihe/türe göredir,
    /// fingerprint'e göre değil); yalnızca `content.userInfo["fingerprint"]` değişir ve
    /// bu, ikinci bir `add()` çağrısını tetikler — `UNUserNotificationCenter`'ın kendi
    /// replace garantisiyle eskisi silinmeden değişir (silme YOK).
    func testSameIdentifierDifferentFingerprintTriggersReplaceAdd() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule(daysFromNow: [1])

        await scheduler.reschedule(from: schedule, config: makeConfig(silent: false))
        let idsBefore = Set(mock.pending.keys)
        XCTAssertFalse(idsBefore.isEmpty)
        let firstAddCount = mock.addCallCount

        let result = await scheduler.reschedule(from: schedule, config: makeConfig(silent: true))
        let idsAfter = Set(mock.pending.keys)

        // Identifier'lar STABİL: fingerprint identifier'da değil, aynı ID'ler korunur.
        XCTAssertEqual(idsBefore, idsAfter, "stabil ID şemasında identifier'lar config değişince değişmemeli")
        // Ama içerik değiştiği için (silent), her identifier için add() TEKRAR çağrılmış olmalı.
        XCTAssertGreaterThan(mock.addCallCount, firstAddCount, "fingerprint değişince tekrar add() çağrılmalı")
        XCTAssertTrue(mock.removedIdentifiers.isEmpty, "aynı-ID replace silme İÇERMEMELİ")
        XCTAssertEqual(result.removed, 0)

        // İkinci add() çağrılarının içeriği gerçekten farklı (fingerprint) olmalı.
        let firstRoundFingerprints = Dictionary(uniqueKeysWithValues:
            mock.addedRequests.prefix(firstAddCount).map { ($0.identifier, $0.content.userInfo["fingerprint"] as? String) })
        let secondRoundFingerprints = Dictionary(uniqueKeysWithValues:
            mock.addedRequests.suffix(from: firstAddCount).map { ($0.identifier, $0.content.userInfo["fingerprint"] as? String) })
        for (id, secondFingerprint) in secondRoundFingerprints {
            XCTAssertNotEqual(firstRoundFingerprints[id] ?? nil, secondFingerprint,
                               "\(id) için ikinci add() çağrısının fingerprint'i ilkinden farklı olmalı")
        }
    }

    // MARK: - (e) Trigger saati değişince (config aynı, vakit kayıyor) yeni add() tetiklenir

    /// Aynı ayarlarla ama Diyanet verisi güncellenip vaktin saati kaydığı senaryo: ID hâlâ
    /// aynı (tarih değişmedi) ama fingerprint (trigger saat/dakika) değişti → replace add().
    func testTriggerTimeDriftWithSameConfigTriggersReplaceAdd() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let config = makeConfig()

        await scheduler.reschedule(from: makeSchedule(daysFromNow: [1], fajrMinuteOffset: 5 * 60), config: config)
        let fajrID = mock.pending.keys.first { $0.contains(".main.fajr.") }
        XCTAssertNotNil(fajrID)
        let firstAddCount = mock.addCallCount
        let firstFingerprint = mock.pending[fajrID!]?.content.userInfo["fingerprint"] as? String

        // İmsak 15 dakika kaydı (aynı takvim günü, aynı config) — ID aynı kalmalı.
        await scheduler.reschedule(from: makeSchedule(daysFromNow: [1], fajrMinuteOffset: 5 * 60 + 15), config: config)

        XCTAssertEqual(Set(mock.pending.keys).contains(fajrID!), true, "vakit kayınca ID değişmemeli")
        XCTAssertGreaterThan(mock.addCallCount, firstAddCount, "vakit kayınca replace add() tetiklenmeli")
        let secondFingerprint = mock.pending[fajrID!]?.content.userInfo["fingerprint"] as? String
        XCTAssertNotEqual(firstFingerprint, secondFingerprint, "trigger saati fingerprint'e girmeli")
    }

    // MARK: - Pencere ileri kaydığında yalnızca yeni günler eklenir

    func testExtendingWindowOnlyAddsNewDaysKeepsExisting() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let config = makeConfig()

        await scheduler.reschedule(from: makeSchedule(daysFromNow: [1, 2]), config: config)
        let idsAfterFirst = Set(mock.pending.keys)

        await scheduler.reschedule(from: makeSchedule(daysFromNow: [1, 2, 3]), config: config)
        let idsAfterSecond = Set(mock.pending.keys)

        // İlk pencerede zamanlanan hiçbir şey kaldırılmamış olmalı.
        XCTAssertTrue(idsAfterFirst.isSubset(of: idsAfterSecond))
        XCTAssertTrue(mock.removedIdentifiers.isEmpty)
    }

    // MARK: - (a) Eş zamanlı iki reschedule() — HER İKİSİ de kendi doğru sonucunu alır

    /// Gerçek FIFO + tek drain task garantisi: coalescing/ezme yok. İki eşzamanlı çağrı
    /// sırayla işlenir; ikincisi çalıştığında ilkinin eklediği identifier'lar zaten pending
    /// olduğundan (aynı config → aynı fingerprint) ikinci çağrının `added` sayısı 0,
    /// `requested` sayısı ilkiyle aynı olmalı — hiçbir sonuç diğerininkiyle EZİLMEMİŞ olmalı.
    func testConcurrentReschedulesEachGetTheirOwnCorrectResult() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule(daysFromNow: [1, 2, 3])
        let config = makeConfig()

        async let first = scheduler.reschedule(from: schedule, config: config)
        async let second = scheduler.reschedule(from: schedule, config: config)
        let (r1, r2) = await (first, second)

        // Aynı config → aynı istenen set boyutu.
        XCTAssertEqual(r1.requested, r2.requested)
        XCTAssertGreaterThan(r1.requested, 0)
        // Toplamda TÜM istenen identifier'lar tam bir kez eklenmiş olmalı (ikinci çağrı
        // ilkinin sonucunu görüp tekrar eklememeli) — coalescing olsaydı biri "0 requested"
        // gibi anlamsız/ezilmiş bir sonuç alabilirdi.
        XCTAssertEqual(mock.pending.count, r1.requested)
        XCTAssertTrue(r1.isFullSuccess)
        XCTAssertTrue(r2.isFullSuccess)
    }

    // MARK: - (c) Kapasite hesabı GERÇEK pending sayısına göre, 64'ü aşmaz, sığmayan deferred'e gider

    func testCapacityIsComputedFromRealPendingCountAndDefersOverflow() async {
        let mock = MockNotificationCenter()
        // Bu scheduler'a ait OLMAYAN (başka bir özelliğin) 63 pending kaydı — silinmemeli,
        // ama kapasiteyi düşürmeli: 64 - 63 = 1 kalan slot.
        mock.seed((0..<63).map { fakeRequest(identifier: "other.feature.notification.\($0)") })

        let scheduler = RollingScheduler(center: mock)
        // Bol miktarda gün → istenen set kesinlikle 1'den fazla olacak.
        let schedule = makeSchedule(daysFromNow: Array(1...10))
        let config = makeConfig()

        let result = await scheduler.reschedule(from: schedule, config: config)

        XCTAssertGreaterThan(result.requested, 1, "test yeterince aday üretmeli")
        XCTAssertLessThanOrEqual(mock.pending.count, RollingScheduler.hardLimit,
                                  "gerçek pending asla 64'ü aşmamalı")
        XCTAssertEqual(result.added, 1, "yalnızca kalan 1 slot kadar eklenebilmeli")
        XCTAssertEqual(result.deferred, result.requested - 1, "sığmayanların tamamı deferred'e gitmeli")
        XCTAssertFalse(result.isFullSuccess)
        // Yabancı kayıtlara dokunulmamalı.
        XCTAssertEqual(mock.removedIdentifiers.count, 0)
    }

    // MARK: - (d) v1/legacy ID'ler silinir, v2 VE tanınmayan yabancı ID'ler SİLİNMEZ

    func testLegacyIdentifiersRemovedButV2AndUnknownIdentifiersSurvive() async {
        let mock = MockNotificationCenter()
        // Hiç var olmamış varsayımsal "sekine.rolling." önekli eski kayıt (v1Prefix kuralı
        // yalnızca bunu yakalar — gerçek production'da hiç üretilmedi, yine de zararsızca
        // hedeflenmeye devam etmeli).
        mock.seed([fakeRequest(identifier: "sekine.rolling.friday-weekly-abc123")])
        // GERÇEK (production) v1 şeması — önek'siz. Bkz. bu dosyanın bir önceki halinin
        // git geçmişi: `"\(prayer.rawValue)-\(main|pre)-\(epoch)"`, `"holy-\(dateKey)"`,
        // `"verse-\(dateKey)"`, `"friday-weekly"`.
        mock.seed([fakeRequest(identifier: "fajr-main-1234567890")])
        mock.seed([fakeRequest(identifier: "isha-pre-1234567890")])
        mock.seed([fakeRequest(identifier: "holy-2026-09-10")])
        mock.seed([fakeRequest(identifier: "verse-2026-09-10")])
        mock.seed([fakeRequest(identifier: "friday-weekly")])
        // Başka bir özelliğe ait, TANINMAYAN identifier — asla dokunulmamalı. Bilinçli
        // olarak "main"/"pre" ve tarih benzeri parçalar içerir ki regex'in gerçekten TAM
        // eşleşme aradığını (alt-string değil) doğrulasın.
        mock.seed([fakeRequest(identifier: "com.other.feature.reminder")])
        mock.seed([fakeRequest(identifier: "com.other.feature.fajr-main-123-extra")])
        mock.seed([fakeRequest(identifier: "com.other.feature.holy-2026-09-10-extra")])

        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule(daysFromNow: [1])
        let config = makeConfig()

        let result = await scheduler.reschedule(from: schedule, config: config)

        let expectedRemoved: Set<String> = [
            "sekine.rolling.friday-weekly-abc123", "fajr-main-1234567890", "isha-pre-1234567890",
            "holy-2026-09-10", "verse-2026-09-10", "friday-weekly"
        ]
        for id in expectedRemoved {
            XCTAssertTrue(mock.removedIdentifiers.contains(id), "GERÇEK eski format silinmeli: \(id)")
        }
        XCTAssertFalse(mock.removedIdentifiers.contains("com.other.feature.reminder"),
                        "tanınmayan/yabancı bir identifier ASLA silinmemeli")
        XCTAssertFalse(mock.removedIdentifiers.contains("com.other.feature.fajr-main-123-extra"),
                        "önek taşıyan yabancı bir identifier, alt-string eşleşmesiyle YANLIŞLIKLA silinmemeli")
        XCTAssertFalse(mock.removedIdentifiers.contains("com.other.feature.holy-2026-09-10-extra"),
                        "önek taşıyan yabancı bir identifier, alt-string eşleşmesiyle YANLIŞLIKLA silinmemeli")
        XCTAssertNotNil(mock.pending["com.other.feature.reminder"])
        XCTAssertNotNil(mock.pending["com.other.feature.fajr-main-123-extra"])
        XCTAssertNotNil(mock.pending["com.other.feature.holy-2026-09-10-extra"])
        XCTAssertEqual(result.removed, expectedRemoved.count)
        // Yeni v2 kayıtları eklendikten sonra hiçbiri v1/legacy önekiyle çakışmıyor olmalı.
        XCTAssertTrue(mock.pending.keys.allSatisfy {
            $0.hasPrefix(RollingScheduler.v2Prefix) || $0.hasPrefix("com.other.feature.")
        })
    }

    // MARK: - v2 namespace İÇİNDE artık istenmeyen kayıtlar silinir (P0 fix)

    /// Bir vakit bildirimi kapatılınca (veya pencere küçülünce) v2 namespace'te kalan
    /// "artık istenmeyen" kayıtlar hiç silinmiyordu — bu, v1/legacy silme adımından AYRI
    /// bir kuralla (v2Prefix + desired'de yok) test edilir.
    func testStaleV2IdentifiersNoLongerDesiredAreRemoved() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule(daysFromNow: [1])

        // İlk turda İkindi (asr) dahil tüm vakitler açık.
        await scheduler.reschedule(from: schedule, config: makeConfig())
        let asrID = mock.pending.keys.first { $0.contains(".main.asr.") }
        XCTAssertNotNil(asrID, "ilk turda asr bildirimi zamanlanmış olmalı")

        // İkinci turda kullanıcı İkindi bildirimini kapatıyor.
        var configWithoutAsr = makeConfig()
        configWithoutAsr.enabledPrayers.remove(.asr)
        let result = await scheduler.reschedule(from: schedule, config: configWithoutAsr)

        XCTAssertTrue(mock.removedIdentifiers.contains(asrID!),
                       "artık istenmeyen v2 kaydı silinmeli")
        XCTAssertNil(mock.pending[asrID!])
        XCTAssertGreaterThan(result.removed, 0)
        // Hâlâ istenen diğer vakitler (ör. öğle) yerinde kalmalı.
        XCTAssertTrue(mock.pending.keys.contains { $0.contains(".main.dhuhr.") })
    }

    // MARK: - BGTask expirationHandler sinyali: mevcut iş yarım bırakılmaz, kalan iş
    // deferred'e gider (P1 fix)

    /// `markExpired()` çağrıldığında, o an süren `add()` döngüsü YARIM BIRAKILMAZ (o anki
    /// `add()` tamamlanır) ama bir SONRAKİ elemana geçmeden önce döngü durur — kalanlar
    /// kaybolmaz, `deferred` sayılır. Zamanlama doğası gereği (actor hop'u + spawn edilen
    /// `Task`) tam sınırda kesin bir sayı garanti edilemez; bu yüzden assertion'lar
    /// mekanizmanın ÇALIŞTIĞINI (bir noktada durduğunu, hiçbir şeyin kaybolmadığını)
    /// doğrular, tam add() sayısını sabitlemez.
    func testExpirationSignalStopsFurtherAddsAndDefersRemainder() async {
        let mock = ExpiringAfterNAddsNotificationCenter(triggerAt: 3)
        let scheduler = RollingScheduler(center: mock)
        let token = RollingScheduler.RescheduleToken()
        mock.scheduler = scheduler
        mock.tokenToExpire = token
        // Bol miktarda gün → istenen set triggerAt'ten kesinlikle fazla olacak.
        let schedule = makeSchedule(daysFromNow: Array(1...10))
        let config = makeConfig()

        let result = await scheduler.reschedule(from: schedule, config: config, token: token)

        XCTAssertGreaterThan(result.requested, 3, "test yeterince aday üretmeli")
        XCTAssertFalse(result.isFullSuccess, "expire sinyali sonrası tam başarı raporlanmamalı")
        XCTAssertGreaterThan(result.deferred, 0, "expire sonrası kalan elemanlar deferred sayılmalı")
        XCTAssertEqual(result.requested, result.added + result.deferred + result.failed,
                        "hiçbir istenen eleman sessizce kaybolmamalı")
        // Expire sinyalinden makul ölçüde kısa süre sonra döngü durmuş olmalı — istenen
        // setin TAMAMI eklenmemiş olmalı.
        XCTAssertLessThan(mock.addCallCount, result.requested)
    }

    /// P1 fix: iş A tamamlanıp GECİKMİŞ expire sinyali gelince (A'nın `markExpired()`
    /// çağrısı ayrı bir `Task` içinde asenkron çalıştığı için A bittikten SONRA aktive
    /// olabilir), kuyrukta bekleyen/yeni gelen iş B bundan ETKİLENMEMELİ — B kendi
    /// token'ıyla normal çalışmalı. Önceki (global `isExpired` bayraklı) implementasyonda
    /// bu senaryoda B de expired sayılıp gereksiz yere deferred'e giderdi.
    func testDelayedExpirationSignalForFinishedJobDoesNotAffectNextJob() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let tokenA = RollingScheduler.RescheduleToken()

        // İş A normal şekilde tamamlanır (kendi token'ıyla).
        let scheduleA = makeSchedule(daysFromNow: [1])
        let resultA = await scheduler.reschedule(from: scheduleA, config: makeConfig(), token: tokenA)
        XCTAssertTrue(resultA.isFullSuccess, "iş A expire sinyali olmadan tam başarıyla bitmeli")

        // A'nın BGTask'ine ait GECİKMİŞ expire sinyali, A bittikten SONRA gelir (ör.
        // `expirationHandler` ile `setTaskCompleted` arasındaki yarış).
        await scheduler.markExpired(tokenA)
        for _ in 0..<5 { await Task.yield() }

        // B, KENDİ (farklı) token'ıyla, A'nın işi bittikten sonra çalışır — A'ya ait
        // gecikmiş sinyalden etkilenmemeli.
        let tokenB = RollingScheduler.RescheduleToken()
        let scheduleB = makeSchedule(daysFromNow: [2, 3, 4])
        let resultB = await scheduler.reschedule(from: scheduleB, config: makeConfig(), token: tokenB)

        XCTAssertTrue(resultB.isFullSuccess, "B, A'ya ait gecikmiş expire sinyalinden ETKİLENMEMELİ")
        XCTAssertEqual(resultB.deferred, 0, "B'nin hiçbir elemanı yanlışlıkla deferred'e gitmemeli")
    }

    /// P1 fix: iş A hâlâ kuyrukta beklerken (ya da kendi koşusu başlarken) expiration
    /// sinyali GELİRSE, A doğru şekilde etkilenmeli — token bazlı mekanizma yalnızca
    /// "geçmiş işi başka işe sızdırma" değil, "kendi işini doğru etkileme" davranışını da
    /// korumalı.
    func testExpirationSignalForOwnTokenAffectsThatJobEvenBeforeItStarts() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let token = RollingScheduler.RescheduleToken()

        // Sinyal, iş kuyruğa/actor'a hiç girmeden ÖNCE gelir — A henüz başlamamışken.
        await scheduler.markExpired(token)
        for _ in 0..<5 { await Task.yield() }

        let schedule = makeSchedule(daysFromNow: Array(1...10))
        let result = await scheduler.reschedule(from: schedule, config: makeConfig(), token: token)

        XCTAssertGreaterThan(result.requested, 0, "test yeterince aday üretmeli")
        XCTAssertFalse(result.isFullSuccess, "önceden işaretlenmiş token için tam başarı raporlanmamalı")
        XCTAssertEqual(result.added, 0, "iş, kendi token'ı zaten expired iken hiçbir şey eklememeli")
        XCTAssertEqual(result.deferred, result.requested,
                        "kendi token'ı expired olan işin TÜM istenen elemanları deferred sayılmalı")
    }

    // MARK: - VISION P1 turu: kuyrukta bekleyen expired iş sonsuza kadar beklemez

    /// P1 fix #1: İş B kuyrukta beklerken (İş A hâlâ sürerken, henüz hiç başlamamışken)
    /// expire sinyali gelirse B, A'nın bitmesini beklemeden HEMEN boş/deferred bir sonuçla
    /// tamamlanmalı — önceden B, A bitene kadar (ve muhtemelen ondan sonra da normal
    /// sırasında) kuyrukta beklerdi; BGTask'in `setTaskCompleted` için beklediği makul süre
    /// içinde bu asla dönmeyebilirdi.
    func testExpiredQueuedJobIsCompletedImmediatelyWithoutWaitingForItsTurn() async {
        let mock = GatedNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let tokenA = RollingScheduler.RescheduleToken()
        let tokenB = RollingScheduler.RescheduleToken()

        // İş A, ilk pending snapshot adımında (gate) askıda kalır — drain task meşgul olur,
        // arkasından gelen İş B kuyrukta BEKLEMEYE başlar (henüz hiç başlamamış).
        async let resultA = scheduler.reschedule(
            from: makeSchedule(daysFromNow: [1]), config: makeConfig(), token: tokenA)
        await mock.gate.waitForArrival()

        async let resultB = scheduler.reschedule(
            from: makeSchedule(daysFromNow: [2]), config: makeConfig(), token: tokenB)
        // B'nin kuyruğa GERÇEKTEN ulaştığını KESİN olarak doğrula — sabit sayıda
        // `Task.yield()` bir TAHMİNDİR ve bu paketin geri kalanı ne kadar iş yapmış olursa
        // olsun (önceki testlerin bıraktığı zamanlama koşulları dahil) her zaman yeterli
        // olacağı garanti edilemez. Yetersiz kalırsa `markExpired` B'yi kuyrukta bulamaz,
        // `expiredTokens`'a yazar; B ise A bitmeden (A, gate'te askıda) hiç başlamayacağı
        // için test SONSUZA KADAR `await resultB`'de kilitlenirdi — tam olarak canlıda
        // yaşanan kilitlenmenin kaynağı buydu. Bu yüzden burada sınırlı bir poll ile
        // KESİN olarak bekleniyor; makul sürede gerçekleşmezse kilitlenmek yerine test
        // BAŞARISIZ olur.
        let deadline = Date().addingTimeInterval(5)
        while await !scheduler.isTokenQueuedForTesting(tokenB) {
            guard Date() < deadline else {
                XCTFail("B, makul sürede kuyruğa ulaşmadı — markExpired'ın 'kuyrukta bekleyen işi hemen tamamla' yolu test edilemez")
                await mock.gate.open()
                _ = await (resultA, resultB)
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        // B HÂLÂ kuyrukta beklerken (A bitmeden ÖNCE) expire sinyali gelir.
        await scheduler.markExpired(tokenB)

        let bResult = await resultB
        XCTAssertEqual(
            bResult, RescheduleResult(requested: 1, added: 0, removed: 0, failed: 0, deferred: 1),
            "kuyrukta bekleyen expired iş, A'yı beklemeden HEMEN boş/deferred sonuçla tamamlanmalı")

        // A hâlâ tamamlanmamış olmalı (gate henüz açılmadı) — B'nin erken tamamlanması
        // A'nın kendi çalışmasını etkilemez/yarım bırakmaz.
        await mock.gate.open()
        let aResult = await resultA
        XCTAssertTrue(aResult.isFullSuccess, "A, B'nin expire edilmesinden etkilenmeden normal tamamlanmalı")
    }

    // MARK: - VISION P1 turu: markExpired token temizliğiyle yarışsız (gerçek concurrency)

    /// P1 fix #2: `markExpired` artık actor-izoleli, senkron bir metot — içeride fire-and-
    /// forget bir `Task` SPAWN ETMEZ. Bu test, işin tamamlanmasıyla `markExpired` çağrısını
    /// GERÇEKTEN eşzamanlı (birbirini `Task.yield()` ile SIRALAMADAN, `async let` ile)
    /// gönderir — hangisinin actor'a önce ulaştığı platforma bağlı, bilinçli olarak kontrol
    /// edilmez. Önceki (fire-and-forget) tasarımda bu, iş bitip kendi token'ını temizledikten
    /// SONRA gecikmiş bir `Task`'in token'ı geri ekleyip kalıcı sızdırmasına açıktı; yeni
    /// tasarımda ya sinyal işe yetişir (deferred sayılır) ya da iş zaten bitmiş olur ve
    /// sinyal (TTL'li Dictionary'de en fazla `expiredTokenTTL` kadar yaşayarak) kalıcı
    /// sızıntıya YOL AÇMAZ. Hangi sırayla sonuçlanırsa sonuçlansın: hiçbir eleman
    /// kaybolmaz/çift sayılmaz VE sonraki, alakasız bir iş bundan etkilenmez.
    func testMarkExpiredRealConcurrencyWithJobCompletionNeverLosesWorkOrLeaksToFutureJobs() async {
        let mock = MockNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let token = RollingScheduler.RescheduleToken()
        let schedule = makeSchedule(daysFromNow: Array(1...5))

        async let result = scheduler.reschedule(from: schedule, config: makeConfig(), token: token)
        async let mark: Void = scheduler.markExpired(token)
        let r = await result
        _ = await mark

        XCTAssertEqual(
            r.requested, r.added + r.deferred + r.failed,
            "yarışın hangi sırayla sonuçlandığından bağımsız, hiçbir istenen eleman kaybolmamalı/çift sayılmamalı")

        let leftoverCount = await scheduler.expiredTokenCountForTesting
        XCTAssertLessThanOrEqual(leftoverCount, 1, "yarıştan yalnızca TEK bir token'lık iz kalabilir, sınırsız birikmemeli")

        // Yarıştan HEMEN sonra, tamamen farklı bir token'la yeni bir iş normal (expire
        // edilmemiş) şekilde çalışabilmeli — önceki token'a ait hiçbir kalıntı, alakasız
        // bir sonraki işi etkilemez.
        let nextToken = RollingScheduler.RescheduleToken()
        let nextResult = await scheduler.reschedule(
            from: makeSchedule(daysFromNow: [10]), config: makeConfig(), token: nextToken)
        XCTAssertTrue(nextResult.isFullSuccess, "önceki yarıştan kalan hiçbir durum sonraki farklı token'lı işi etkilememeli")
    }

    /// P1 (bilinen risk): expire edilmiş AKTİF bir işin işareti, başka bir işin `markExpired`
    /// çağrısındaki TTL süpürmesiyle silinmemeli. TTL=0 ile "süre çoktan doldu" simüle edilir:
    /// düzeltmeden önce A'nın işareti süpürülür, A kalan bütün elemanları eklemeye devam ederdi.
    func testActiveExpiredJobMarkerSurvivesTTLSweepFromAnotherToken() async {
        let mock = SweepingExpiryNotificationCenter(triggerAt: 3)
        let scheduler = RollingScheduler(center: mock, expiredTokenTTL: 0)
        let token = RollingScheduler.RescheduleToken()
        mock.scheduler = scheduler
        mock.tokenToExpire = token

        let result = await scheduler.reschedule(
            from: makeSchedule(daysFromNow: Array(1...10)), config: makeConfig(), token: token)

        XCTAssertGreaterThan(result.deferred, 0, "expire edilen aktif iş kalanını ertelemeli")
        XCTAssertLessThan(mock.addCallCount, result.requested)
        XCTAssertEqual(result.requested, result.added + result.deferred + result.failed)
    }

    // MARK: - Başarısız add() sessizce yutulmaz

    func testFailedAddIsCountedAndReported() async {
        let mock = AlwaysFailingNotificationCenter()
        let scheduler = RollingScheduler(center: mock)
        let schedule = makeSchedule(daysFromNow: [1])

        let result = await scheduler.reschedule(from: schedule, config: makeConfig())

        XCTAssertGreaterThan(result.failed, 0, "test add() başarısızlığını gerçekten simüle etmeli")
        XCTAssertFalse(result.isFullSuccess)
    }
}

/// Her `add()` çağrısını başarısız kılan mock — kısmi başarısızlık raporlamasını
/// doğrulamak için. `NotificationScheduling`'in `removePendingNotificationRequests`
/// gereksinimi senkron (non-async) olduğu için bu bir `actor` OLAMAZ.
/// `@unchecked Sendable`: testte yalnızca tek bir `RollingScheduler` (actor) tarafından
/// sırayla `await` edilerek kullanılır, gerçek eş zamanlı erişim yoktur.
private final class AlwaysFailingNotificationCenter: NotificationScheduling, @unchecked Sendable {
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func add(_ request: UNNotificationRequest) async throws {
        throw NSError(domain: "AlwaysFailingNotificationCenter", code: 1)
    }
}

/// `N`. `add()` çağrısında bağlı `RollingScheduler`'ın `markExpired()`'ını tetikleyip
/// birkaç `Task.yield()` ile actor'un spawn ettiği expire-set Task'ının bu turda gerçekten
/// çalışmasına fırsat veren mock — BGTask expirationHandler'ın gerçek zamanlamasını
/// simüle eder (bkz. `testExpirationSignalStopsFurtherAddsAndDefersRemainder`).
/// `@unchecked Sendable`: yalnızca testte, tek bir `RollingScheduler` tarafından sırayla
/// `await` edilerek kullanılır.
private final class ExpiringAfterNAddsNotificationCenter: NotificationScheduling, @unchecked Sendable {
    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var addCallCount = 0
    private(set) var removedIdentifiers: [String] = []
    private let triggerAt: Int
    /// Test tarafından `RollingScheduler` yaratıldıktan hemen sonra atanır (döngüsel
    /// başlatma sırası nedeniyle init'te enjekte edilemez).
    var scheduler: RollingScheduler?
    /// Test tarafından, `scheduler.reschedule(...)`'a verilen AYNI token atanır — böylece
    /// bu mock, "hangi koşuyu expire edeceğini" gerçek bir BGTask expirationHandler'ı gibi
    /// bilir (global bir bayrak değil, o koşuya özel token).
    var tokenToExpire: RollingScheduler.RescheduleToken?

    init(triggerAt: Int) { self.triggerAt = triggerAt }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { Array(pending.values) }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        for id in identifiers { pending.removeValue(forKey: id) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
        pending[request.identifier] = request
        if addCallCount == triggerAt, let tokenToExpire {
            await scheduler?.markExpired(tokenToExpire)
            for _ in 0..<20 { await Task.yield() }
        }
    }
}

/// Test yalnızca tek bir çağrının askıya alınıp alınmadığını bilmek yerine (yarış
/// koşullarını `Task.yield()` sayısı tahmin ederek değil) kesin olarak "askıdayım" ve
/// "artık devam edebilirsin" sinyallerini verebilsin diye küçük bir randevu (rendezvous)
/// actor'ü — `GatedNotificationCenter`'ın `pendingNotificationRequests()` çağrısını
/// `open()` çağrılana kadar askıda tutar.
private actor Gate {
    private var opened = false
    /// `wait()` zaten en az bir kez çağrıldı mı — `waitForArrival()`'ın, `wait()`'ten
    /// SONRA çağrılma ihtimaline karşı sonsuza kadar askıda kalmaması için (bir bayrak
    /// olmadan, yalnızca tek bir "gelince haber ver" continuation'ı tutmak, `wait()` ondan
    /// ÖNCE çalışırsa continuation henüz `nil` olduğundan sinyal kaybolur ve deadlock
    /// oluşurdu — bu tam olarak ilk sürümde yaşanan hataydı).
    private var arrived = false
    private var openWaiters: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []

    /// Çağıran, `wait()`'in gerçekten çağrıldığından (askıya girmiş olsun ya da olmasın)
    /// emin olmak için bunu `await` eder. `wait()` bundan ÖNCE de SONRA da çağrılmış
    /// olabilir — `arrived` bayrağı hangi sırayla geldiklerinden bağımsız doğru sonucu
    /// garanti eder.
    func waitForArrival() async {
        if arrived { return }
        await withCheckedContinuation { arrivalWaiters.append($0) }
    }

    func wait() async {
        arrived = true
        for w in arrivalWaiters { w.resume() }
        arrivalWaiters = []
        if opened { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func open() {
        opened = true
        for w in openWaiters { w.resume() }
        openWaiters = []
    }
}

/// `pendingNotificationRequests()` çağrısını dışarıdan kontrol edilen bir `Gate` ile
/// askıda tutan mock — "İş A hâlâ sürüyor/bitmemiş" durumunu Task.yield() sayısı tahmin
/// ederek DEĞİL, kesin bir randevu ile simüle etmek için (bkz.
/// `testExpiredQueuedJobIsCompletedImmediatelyWithoutWaitingForItsTurn`).
/// `@unchecked Sendable`: yalnızca testte, tek bir `RollingScheduler` (actor) tarafından
/// sırayla `await` edilerek kullanılır.
private final class GatedNotificationCenter: NotificationScheduling, @unchecked Sendable {
    let gate = Gate()
    private(set) var pending: [String: UNNotificationRequest] = [:]

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await gate.wait()
        return Array(pending.values)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { pending.removeValue(forKey: id) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending[request.identifier] = request
    }
}

/// `add()` N. çağrıda: önce koşuyu expire eder, sonra BAŞKA bir token için `markExpired`
/// çağırarak (TTL süpürmesi) aktif işin işaretini silmeye çalışır.
private final class SweepingExpiryNotificationCenter: NotificationScheduling, @unchecked Sendable {
    private(set) var pending: [String: UNNotificationRequest] = [:]
    private(set) var addCallCount = 0
    private let triggerAt: Int
    var scheduler: RollingScheduler?
    var tokenToExpire: RollingScheduler.RescheduleToken?

    init(triggerAt: Int) { self.triggerAt = triggerAt }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { Array(pending.values) }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { pending.removeValue(forKey: id) }
    }
    func add(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
        pending[request.identifier] = request
        if addCallCount == triggerAt, let tokenToExpire {
            await scheduler?.markExpired(tokenToExpire)
            await scheduler?.markExpired(RollingScheduler.RescheduleToken())   // süpürmeyi tetikler
            for _ in 0..<20 { await Task.yield() }
        }
    }
}
