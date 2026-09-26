import Foundation
import UserNotifications

struct SchedulerConfig: Sendable {
    var enabledPrayers: Set<Prayer>
    var sound: NotificationSound
    /// Premium: vakit-başına özel ses (yoksa `sound`).
    var perPrayerSounds: [Prayer: NotificationSound] = [:]
    var silent: Bool
    var preReminderMinutes: Int
    /// Kullanıcı onayıyla Odak/Uyku/DND'yi delme (opt-in).
    var breakThroughFocus: Bool
    // Ek hatırlatmalar (varsayılan açık; ayarlardan kapatılabilir).
    var fridayReminder: Bool
    var fridayReminderHour: Int
    var specialDayGreetings: Bool
    var dailyVerse: Bool
    var dailyVerseHour: Int
}

/// `RollingScheduler`'ın kullandığı `UNUserNotificationCenter` yüzeyi. Testlerde gerçek
/// bildirim merkezi yerine sahte bir implementasyon enjekte edebilmek için (identifier-diff
/// mantığını simülatör/cihaz olmadan doğrulamak amacıyla) protokol seam'i.
protocol NotificationScheduling: Sendable {
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationScheduling {}

/// Bir `reschedule()` çağrısının gerçek sonucu — çağıranlar "sessizce başarılı" varsaymak
/// yerine kısmi başarısızlığı/ertelemeyi görüp loglayabilsin/tekrar deneyebilsin diye.
/// `deferred`: bu turda 64-limit yüzünden eklenemeyen, bir sonraki reconciliation'a
/// bırakılan istek sayısı (kaybolmaz, sessizce atlanmaz).
struct RescheduleResult: Sendable, Equatable {
    var requested: Int
    var added: Int
    var removed: Int
    var failed: Int
    var deferred: Int

    var isFullSuccess: Bool { failed == 0 && deferred == 0 }
}

/// iOS aynı anda EN FAZLA 64 zamanlanmış yerel bildirim tutar. Rakiplerin
/// "bildirimler bir süre sonra duruyor" hatası, bu pencereyi tazelememelerinden
/// kaynaklanır. RollingScheduler her tetiklenişte gelecekteki ilk N vakti yeniden
/// zamanlar; app açılışı, arka plan görevi ve bildirim tetiklenişi bunu tazeler.
///
/// **Tek kanonik instance şart.** Bu tip bir `actor` olsa da, actor izolasyonu yalnızca
/// TEK bir instance içinde geçerlidir — uygulamanın farklı yerleri (ör. `PrayerTimeStore`
/// ve arka plan görevleri) kendi ayrı instance'larını yaratırsa aynı
/// `UNUserNotificationCenter`'a eşzamanlı, izole edilmemiş erişim mümkün olur. Composition
/// root `SekineApp.init()`'tir: TEK bir `RollingScheduler` orada yaratılır, hem
/// `PrayerTimeStore`'a hem `AppDelegate`/`BackgroundRefresh`'e o instance enjekte edilir
/// (bkz. `Sekine/App/SekineApp.swift`, `Sekine/App/AppDelegate.swift`,
/// `Sekine/App/BackgroundRefresh.swift`). Kimse kendi instance'ını yaratmaz.
///
/// **Sıralama garantisi — gerçek FIFO + tek drain task.** Her `reschedule()` çağrısı kendi
/// `CheckedContinuation`'ıyla bir kuyruğa eklenir; kuyruğu TEK bir uzun-ömürlü `Task`
/// (`drainTask`) sırayla tüketir. Coalescing/ezme YOK: iki eşzamanlı çağrı gelirse ikisi de
/// kendi doğru sonucunu alır (biri diğerinin sonucuyla asla ezilmez). Cancellation bilinçli
/// olarak KAPSAM DIŞI — ürünün bir "isteği iptal et" senaryosu yok, bu yüzden
/// `CheckedContinuation<RescheduleResult, Never>` yeterli (bkz. misyon notu, 2026-09-08
/// kapsam sadeleştirme kararı).
///
/// **Stabil identifier + otomatik replace.** Kimlikler fingerprint İÇERMEZ — yalnızca
/// tür+vakit+takvim-tarihinden türetilir (`sekine.rolling.v2.<kind>...`), bu yüzden
/// gün ilerledikçe/vakit kayınca ID değişmez. İçerik değişikliğini yakalamak için
/// fingerprint `content.userInfo["fingerprint"]` içinde tutulur; aynı ID'ye farklı
/// fingerprint'li bir `add()` çağrısı, `UNUserNotificationCenter`'ın kendi garantisiyle
/// eskisini OTOMATİK REPLACE eder — ayrı bir `remove()` gerekmez.
actor RollingScheduler {
    /// iOS'un sabit, aşılamaz sınırı.
    static let hardLimit = 64
    /// "İstenen" seti üretirken kullanılan iç bütçe — hardLimit'ten bağımsız, yalnızca
    /// makul sayıda bildirim üretmek için (gerçek kapasite kontrolü adım 5'te, GERÇEK
    /// pending sayısına göre yapılır).
    static let softBudget = 60
    static let dailyVerseHorizon = 7

    /// Bu scheduler'ın ürettiği TÜM identifier'ların yeni (v2) öneki.
    static let v2Prefix = "sekine.rolling.v2."
    /// Eski (v1) şemanın ortak öneki — v2 ile başlamayan ama bu önekle başlayan HER ŞEY
    /// v1 sayılır ve silinir (dinamik eski fingerprint'li ID'ler dahil).
    static let v1Prefix = "sekine.rolling."
    /// Hiç önek taşımayan, kod tarihinde bilinen sabit eski identifier'lar. Yalnızca bu
    /// TAM eşleşen isimler silinir — tanınmayan/başka bir özelliğe ait hiçbir şeye
    /// dokunulmaz.
    static let knownLegacyIdentifiers: Set<String> = ["friday-weekly"]

    /// GERÇEK (production) v1 şeması hiçbir ortak önek TAŞIMIYORDU — `v1Prefix` yalnızca
    /// hiç var olmamış varsayımsal bir ara şema için yazılmıştı ve gerçek eski kayıtları
    /// asla yakalamıyordu (bkz. `git log` öncesi `RollingScheduler.swift`: identifier'lar
    /// `"\(prayer.rawValue)-\(main|pre)-\(epoch)"`, `"holy-\(dateKey)"`, `"verse-\(dateKey)"`,
    /// `"friday-weekly"` idi — hiçbiri `"sekine.rolling."` ile başlamıyordu). Bu iki regex,
    /// SADECE bu tanınan dört gerçek kalıba TAM uyan isimleri hedefler; rastgele bir
    /// "-main-" veya tarih içeren yabancı bir identifier'a asla dokunmaz.
    private static let legacyMainPreRegex = try! NSRegularExpression(
        pattern: "^(fajr|sunrise|dhuhr|asr|maghrib|isha)-(main|pre)-[0-9]+$")
    private static let legacyDateKeyedRegex = try! NSRegularExpression(
        pattern: "^(holy|verse)-[0-9]{4}-[0-9]{2}-[0-9]{2}$")

    private static func isKnownLegacyV1Format(_ id: String) -> Bool {
        let range = NSRange(id.startIndex..., in: id)
        return legacyMainPreRegex.firstMatch(in: id, range: range) != nil ||
               legacyDateKeyedRegex.firstMatch(in: id, range: range) != nil
    }

    private let center: NotificationScheduling

    // MARK: - Gerçek FIFO + tek drain task

    /// Bir `reschedule()` çağrısını (ve onu işleyecek `performReschedule` koşusunu)
    /// benzersiz şekilde tanımlar. Global bir `isExpired` bayrağı yerine bunun
    /// kullanılmasının nedeni: `markExpired()` ayrı bir `Task` içinde ASENKRON çalışıyor
    /// (bkz. altındaki not) — iş A bitip kuyruktan iş B başladıktan SONRA A'ya ait
    /// GECİKMİŞ bir expire sinyali gelirse, global bir bayrak bunu B'yi de "expired"
    /// sayardı (B'nin kendi BGTask'i hiç expire olmamış olsa bile). Token'lı yaklaşımda
    /// her koşu SADECE KENDİ token'ı işaretlenmişse etkilenir; başka bir koşunun (geçmiş
    /// ya da gelecek) expire sinyali bunu asla etkilemez.
    struct RescheduleToken: Sendable, Hashable {
        private let id = UUID()
    }

    private struct WorkItem {
        let schedule: PrayerSchedule
        let config: SchedulerConfig
        let token: RescheduleToken
        let continuation: CheckedContinuation<RescheduleResult, Never>
    }

    private var queue: [WorkItem] = []
    private var drainTask: Task<Void, Never>?

    /// BGTask `expirationHandler`'ının bildirdiği "artık zamanımız kalmadı" sinyali —
    /// yalnızca içinde bulunduğu `RescheduleToken`'a ait koşuyu etkiler. `Task.cancel()`
    /// bir actor'un içindeki uzun `await` zincirini KESMEZ — cancellation yalnızca kontrol
    /// noktalarında (`Task.isCancelled` kontrolü olan yerlerde) etkili olur. Bu yüzden
    /// dışarıdan çağrılabilen açık bir sinyal gerekiyor: `markExpired(token:)` çağrıldığında,
    /// o token'a ait `performReschedule` (varsa, o an süren ya da kuyrukta bekleyen) YARIM
    /// BIRAKILMAZ — mevcut `add()` döngüsü bir sonraki elemana geçmeden önce bu token'ın
    /// işaretini kontrol edip erken durur, kalanları "deferred" sayar (kaybolmaz, bir
    /// sonraki reconciliation'a kalır). Bir koşu bitince kendi token'ını bu Dictionary'den
    /// temizler; ayrıca her `markExpired` çağrısı TTL'i geçmiş kayıtları süpürür — bkz.
    /// `markExpired` dokümantasyonu (P1 fix #2, token sızıntısı).
    private var expiredTokens: [RescheduleToken: Date] = [:]
    /// `markExpired` ile `performReschedule`'ın kendi token temizliği arasında (BGTask
    /// `expirationHandler`'ın sync closure'dan yalnızca bir `Task` ile `await` edebildiği
    /// gerçek platform kısıtı yüzünden) teorik bir yarış payı kalabilir — bu TTL o payı
    /// SINIRLAR: bir iş bitmeden ÖNCE gelen bir işaret normal akışta ~anında tüketilir
    /// (`defer` ile temizlenir); bir iş bittikten SONRA gelen gecikmiş bir işaret en fazla
    /// bu süre kadar Dictionary'de kalır, sonra otomatik süpürülür — kalıcı sızıntı YOK.
    private let expiredTokenTTL: TimeInterval
    /// Şu an `performReschedule` içinde ÇALIŞAN işlerin token'ları. TTL süpürmesi bunların
    /// expire işaretini ASLA silmez (bilinen risk P1: 60sn'den uzun süren, expire edilmiş
    /// bir işin işareti başka bir işin `markExpired` çağrısıyla süpürülüp iş expire
    /// olmamış gibi devam edebiliyordu).
    private var activeTokens: Set<RescheduleToken> = []

    init(center: NotificationScheduling = UNUserNotificationCenter.current(),
         expiredTokenTTL: TimeInterval = 60) {
        self.center = center
        self.expiredTokenTTL = expiredTokenTTL
    }

    /// `BackgroundRefresh`'in `expirationHandler`'ından (senkron bir closure olduğu için
    /// `Task { await scheduler.markExpired(token) }` şeklinde) çağrılır. Bilinçli olarak
    /// actor-izoleli, `async` OLMAYAN, SENKRON bir metottur — içeride ayrıca fire-and-forget
    /// bir `Task` BAŞLATMAZ. Önceki tasarımda `nonisolated func markExpired` kendi içinde
    /// `Task { await setExpired(token) }` spawn ediyordu; bu, actor'a giren iki bağımsız
    /// zamanlama noktası yaratıyordu (dışarıdaki çağrı Task'i + içerideki spawn edilen
    /// Task'in ne zaman çalışacağı belirsiz) — iş kendi `performReschedule`'ı bitip
    /// `expiredTokens`'ı temizledikten SONRA bu iç Task çalışırsa token GERİ eklenip
    /// KALICI olarak orada sızardı (hiçbir gelecekteki koşu artık o token'ı üretmeyeceği
    /// için hiç temizlenmezdi). Şimdi tek actor-hop var: çağıran `await` ile doğrudan bu
    /// metodu çağırır, metot senkron çalışır. Kuyrukta bekleyen bir iş varsa hemen
    /// tamamlanır (P1 fix #1); aksi halde işaret `expiredTokens`'a yazılır (TTL ile
    /// süpürülür, bkz. yukarı) — hâlâ çalışan bir iş bunu bir sonraki elemana geçmeden
    /// önce görüp erken durur; iş zaten bitmişse (veya iş hiç var olmadıysa, ör. çok erken
    /// gelen bir sinyal) işaret en fazla TTL kadar yaşar, kalıcı sızıntı OLMAZ.
    func markExpired(_ token: RescheduleToken) {
        let now = Date()
        expiredTokens = expiredTokens.filter {
            now.timeIntervalSince($0.value) < expiredTokenTTL || activeTokens.contains($0.key)
        }

        // İş hâlâ kuyrukta bekliyorsa (henüz başlamadıysa) sonsuza kadar beklemesin:
        // kuyruktan hemen çıkar, boş/deferred bir sonuçla tamamla (P1 fix #1).
        if let idx = queue.firstIndex(where: { $0.token == token }) {
            let item = queue.remove(at: idx)
            // `requested == added + deferred + failed` değişmezi (bkz. bilinen risk P2)
            // bu yolda da korunur: hiç başlamamış tek bir iş birimi = 1 istenen, 1 ertelenen.
            item.continuation.resume(returning: RescheduleResult(
                requested: 1, added: 0, removed: 0, failed: 0, deferred: 1))
            return
        }
        expiredTokens[token] = now
    }

    /// Yalnızca testler için: `expiredTokens`'ın o anki boyutu — TTL'li temizliğin gerçekten
    /// sızıntıyı sınırladığını (sonsuza kadar büyümediğini) doğrulamak amacıyla.
    var expiredTokenCountForTesting: Int { expiredTokens.count }

    /// Yalnızca testler için: verilen token'a ait bir iş şu an kuyrukta (henüz başlamamış)
    /// bekliyor mu. "Bir işin kuyruğa ulaştığını" `Task.yield()` sayısı TAHMİN ederek değil,
    /// KESİN olarak doğrulamak için (bkz. `RollingSchedulerTests.testExpiredQueuedJobIsCompletedImmediatelyWithoutWaitingForItsTurn`
    /// — sabit sayıda yield'e güvenmek, önceki testlerin bıraktığı zamanlama koşullarına bağlı
    /// olarak GERÇEKTEN kilitlenen bir deadlock'a yol açtı: iş B kuyruğa ulaşmadan `markExpired`
    /// çalışırsa "hemen tamamla" hızlı yolu yerine `expiredTokens` işaretlenir, ama B kendi
    /// sırasına gelmeden (A bitmeden) hiç başlamadığından test sonsuza kadar `await resultB`'de
    /// asılı kalırdı).
    func isTokenQueuedForTesting(_ token: RescheduleToken) -> Bool {
        queue.contains { $0.token == token }
    }

    /// İstek kuyruğa eklenir; tek bir `drainTask` kuyruğu sırayla tüketir. Her çağıran
    /// KENDİ isteğinin sonucunu alır — coalescing/ezme yok. `token` verilmezse yeni bir
    /// tane üretilir (bu, expire sinyali göndermeyecek sıradan çağıranlar için yeterli);
    /// BGTask expirationHandler'ından `markExpired(_:)` ile eşleştirilecekse çağıran kendi
    /// token'ını üretip hem burada hem `markExpired(_:)`'da aynı değeri kullanmalı.
    @discardableResult
    func reschedule(
        from schedule: PrayerSchedule, config: SchedulerConfig, token: RescheduleToken = RescheduleToken()
    ) async -> RescheduleResult {
        await withCheckedContinuation { (cont: CheckedContinuation<RescheduleResult, Never>) in
            queue.append(WorkItem(schedule: schedule, config: config, token: token, continuation: cont))
            startDrainingIfNeeded()
        }
    }

    private func startDrainingIfNeeded() {
        guard drainTask == nil else { return }
        drainTask = Task { await drain() }
    }

    private func drain() async {
        while !queue.isEmpty {
            let item = queue.removeFirst()
            let result = await performReschedule(from: item.schedule, config: item.config, token: item.token)
            item.continuation.resume(returning: result)
        }
        drainTask = nil
    }

    // MARK: - Reconciliation (5 adım, kesin sıra)

    private func performReschedule(
        from schedule: PrayerSchedule, config: SchedulerConfig, token: RescheduleToken
    ) async -> RescheduleResult {
        // Koşu bitince (erken/normal fark etmez) kendi token'ını temizle — gecikmiş bir
        // `markExpired(token:)` çağrısı bu satırdan sonra gelirse en fazla TTL kadar
        // yaşayıp kendiliğinden süpürülür (bkz. `markExpired` dokümantasyonu), kalıcı
        // sızıntı OLMAZ.
        activeTokens.insert(token)
        defer {
            activeTokens.remove(token)
            expiredTokens.removeValue(forKey: token)
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        let now = Date()

        let desired = buildDesiredItems(from: schedule, now: now, cal: cal, config: config)
        let desiredIDs = Set(desired.map(\.identifier))

        // 1) Mevcut pending'in TAM snapshot'ı.
        let initialPending = await center.pendingNotificationRequests()
        var pendingByID: [String: UNNotificationRequest] = [:]
        for request in initialPending { pendingByID[request.identifier] = request }

        var addedCount = 0
        var failedCount = 0

        // 2) Aynı-ID (v2 namespace) istekler: fingerprint değiştiyse add() (otomatik
        //    replace). Bu adım SİLME içermez, mevcut bildirim sayısını düşürmez.
        //    Expire sinyali gelirse: mevcut elemanı yarım bırakmadan, bir SONRAKİ elemana
        //    geçmeden önce döngüden çıkılır — ziyaret edilmeyenler adım 5'te "deferred"
        //    olarak sayılır (kaybolmaz).
        var handledIDs: Set<String> = []
        for item in desired {
            guard let existing = pendingByID[item.identifier] else { continue }
            if expiredTokens[token] != nil { break }
            handledIDs.insert(item.identifier)
            let existingFingerprint = existing.content.userInfo["fingerprint"] as? String
            guard existingFingerprint != item.fingerprint else { continue } // zaten güncel
            do {
                try await center.add(item.request)
                addedCount += 1
            } catch {
                failedCount += 1
                print("RollingScheduler: replace başarısız (\(item.identifier)): \(error)")
            }
        }

        // 3) v1/legacy identifier'lar silinir. GERÇEK eski şema hiçbir ortak önek
        //    taşımıyordu (bkz. `isKnownLegacyV1Format` dokümantasyonu) — bu yüzden hem
        //    (hiç var olmamış) varsayımsal "sekine.rolling." önekli hem de GERÇEK dört
        //    önek'siz kalıp burada birlikte hedeflenir. Tanınmayan/başka özelliklere ait
        //    hiçbir şeye dokunulmaz. Ağ/gecikme içermez, expire sinyalinden etkilenmez.
        let legacyIDs = pendingByID.keys.filter { id in
            (id.hasPrefix(Self.v1Prefix) && !id.hasPrefix(Self.v2Prefix)) ||
            Self.knownLegacyIdentifiers.contains(id) ||
            Self.isKnownLegacyV1Format(id)
        }
        if !legacyIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(legacyIDs))
        }

        // 3.5) v2 namespace İÇİNDE artık istenmeyen kayıtlar silinir (ör. bir vakit
        //      bildirimi kapatıldı ya da pencere küçüldü) — bu, v1/legacy silme adımından
        //      TAMAMEN AYRI bir adım: v1 "tanınan eski kalıp" kuralını kullanırken, burada
        //      kural basit fark: "v2Prefix ile başlıyor ama bu turun istenen setinde yok".
        let staleV2IDs = pendingByID.keys.filter { id in
            id.hasPrefix(Self.v2Prefix) && !desiredIDs.contains(id)
        }
        if !staleV2IDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleV2IDs))
        }

        // 4) TEKRAR snapshot alınır — gerçek, güncel pending sayısı (tahmin değil).
        let actualCountAfterCleanup = await center.pendingNotificationRequests().count
        var remainingCapacity = max(0, Self.hardLimit - actualCountAfterCleanup)

        // 5) Kalan kapasiteye göre henüz pending olmayan YENİ istekler eklenir;
        //    sığmayanlar (kapasite ya da expire yüzünden) deferred'e gider (kaybolmaz,
        //    sonraki reconciliation'a bırakılır).
        var deferredCount = 0
        for item in desired where !handledIDs.contains(item.identifier) {
            guard expiredTokens[token] == nil else {
                deferredCount += 1
                continue
            }
            guard remainingCapacity > 0 else {
                deferredCount += 1
                continue
            }
            do {
                try await center.add(item.request)
                addedCount += 1
                remainingCapacity -= 1
            } catch {
                failedCount += 1
                print("RollingScheduler: yeni ekleme başarısız (\(item.identifier)): \(error)")
            }
        }

        let result = RescheduleResult(
            requested: desired.count, added: addedCount, removed: legacyIDs.count + staleV2IDs.count,
            failed: failedCount, deferred: deferredCount)
        print("RollingScheduler: reschedule tamam — istenen \(result.requested), eklendi \(result.added), " +
              "kaldırıldı \(result.removed), başarısız \(result.failed), ertelendi \(result.deferred).")
        if !result.isFullSuccess {
            print("RollingScheduler: UYARI — kısmi sonuç, bir sonraki reconciliation'da tekrar denenecek.")
        }
        return result
    }

    // MARK: - İstenen set üretimi (öncelik sırası: Cuma → kandil/bayram → ana vakitler →
    // günlük ayet → ön-hatırlatma; ana vakitler ayet/ön-hatırlatmadan önce zamanlanır ki
    // çekirdek kapsam ekstralar yüzünden azalmasın)

    private struct DesiredItem {
        let identifier: String
        let fingerprint: String
        let request: UNNotificationRequest
    }

    private func buildDesiredItems(
        from schedule: PrayerSchedule, now: Date, cal: Calendar, config: SchedulerConfig
    ) -> [DesiredItem] {
        var items: [DesiredItem] = []
        let budget = Self.softBudget

        // 1) Cuma hatırlatması — haftalık repeating (1 slot, pencere kurusa da gelir).
        if config.fridayReminder {
            items.append(fridayItem(calendar: cal, config: config))
        }

        // 2) Kandil/bayram tebrikleri — penceredeki gelecekteki günler (nadir).
        if config.specialDayGreetings {
            for item in religiousItems(from: schedule, now: now, cal: cal, config: config) {
                if items.count >= budget { break }
                items.append(item)
            }
        }

        // Ana vakit adayları (kronolojik).
        let mains = schedule.days.flatMap(\.times)
            .filter { $0.date > now && config.enabledPrayers.contains($0.prayer) }
            .sorted { $0.date < $1.date }

        // Günlük ayet/dua adayları (sınırlı ufuk).
        let verseCandidates = config.dailyVerse
            ? verseItems(from: schedule, now: now, cal: cal, config: config, limit: Self.dailyVerseHorizon)
            : []

        // 3) Ana vakitler (öncelik). Ayet + bir miktar ön-hatırlatma için yer ayır.
        let preReserve = config.preReminderMinutes > 0 ? 10 : 0
        let mainsBudget = max(0, budget - items.count - verseCandidates.count - preReserve)
        var scheduledMains: [PrayerTime] = []
        for t in mains {
            if scheduledMains.count >= mainsBudget || items.count >= budget { break }
            items.append(mainItem(for: t, calendar: cal, config: config, isPreReminder: false))
            scheduledMains.append(t)
        }

        // 4) Günlük ayet/dua.
        for item in verseCandidates {
            if items.count >= budget { break }
            items.append(item)
        }

        // 5) Ön-hatırlatma (kalan bütçe; yalnızca zamanlanmış ana vakitler için, en yakından).
        if config.preReminderMinutes > 0 {
            for t in scheduledMains {
                if items.count >= budget { break }
                if let preDate = cal.date(byAdding: .minute, value: -config.preReminderMinutes, to: t.date),
                   preDate > now {
                    items.append(mainItem(
                        for: PrayerTime(prayer: t.prayer, date: preDate),
                        calendar: cal, config: config, isPreReminder: true))
                }
            }
        }

        return items
    }

    // MARK: - Ana vakit / ön-hatırlatma bildirimi

    private func mainItem(
        for time: PrayerTime, calendar cal: Calendar, config: SchedulerConfig, isPreReminder: Bool
    ) -> DesiredItem {
        let content = UNMutableNotificationContent()
        let title: String
        let body: String
        if isPreReminder {
            title = "\(time.prayer.displayName) yaklaşıyor"
            body = "\(time.prayer.displayName) vaktine \(config.preReminderMinutes) dakika kaldı."
        } else {
            title = "\(time.prayer.displayName) Vakti"
            body = bodyText(for: time.prayer)
        }
        content.title = title
        content.body = body
        let prayerSound = config.perPrayerSounds[time.prayer] ?? config.sound
        let soundDescriptor = config.silent ? "silent" : prayerSound.rawValue
        if let sound = prayerSound.unSound(silent: config.silent) {
            content.sound = sound
        }
        // Opt-in: yalnızca kullanıcı onay verdiyse Odak/Uyku/DND'yi del.
        let interruptionLevel: UNNotificationInterruptionLevel = config.breakThroughFocus ? .timeSensitive : .active
        content.interruptionLevel = interruptionLevel

        var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: time.date)
        components.timeZone = cal.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let kind = isPreReminder ? "pre" : "main"
        let dateKey = ExtraNotifications.dateKey(time.date, cal)
        let identifier = "\(Self.v2Prefix)\(kind).\(time.prayer.rawValue).\(dateKey)"

        let fingerprint = Self.fingerprint(
            components: components, timeZoneIdentifier: cal.timeZone.identifier,
            title: title, body: body, soundDescriptor: soundDescriptor,
            interruptionLevel: interruptionLevel)
        content.userInfo = ["fingerprint": fingerprint]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        return DesiredItem(identifier: identifier, fingerprint: fingerprint, request: request)
    }

    private func bodyText(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "İmsak vakti girdi."
        case .dhuhr: return "Öğle vakti girdi."
        case .asr: return "İkindi vakti girdi."
        case .maghrib: return "Akşam vakti girdi."
        case .isha: return "Yatsı vakti girdi."
        // Güneş namaz vakti değildir; isNotifiable=false → bildirimi hiç planlanmaz.
        case .sunrise: return ""
        }
    }

    // MARK: - Ek hatırlatmalar

    /// Cuma günü, haftalık tekrarlayan tek bildirim (kalıcı; pencereden bağımsız — tek
    /// slot, `sekine.rolling.v2.friday.weekly`).
    private func fridayItem(calendar cal: Calendar, config: SchedulerConfig) -> DesiredItem {
        let content = UNMutableNotificationContent()
        let title = "Cuma Mübarek Olsun"
        let body = "Kehf suresini okumayı ve salavât-ı şerifeyi unutmayın."
        content.title = title
        content.body = body
        let soundDescriptor = config.silent ? "silent" : config.sound.rawValue
        if let sound = config.sound.unSound(silent: config.silent) {
            content.sound = sound
        }
        let interruptionLevel: UNNotificationInterruptionLevel = .active
        content.interruptionLevel = interruptionLevel

        var comps = DateComponents()
        comps.weekday = 6 // Cuma (Gregoryen: Pazar=1 … Cuma=6)
        comps.hour = config.fridayReminderHour
        comps.minute = 0
        comps.timeZone = cal.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let identifier = "\(Self.v2Prefix)friday.weekly"
        let fingerprint = Self.fingerprint(
            components: comps, timeZoneIdentifier: cal.timeZone.identifier,
            title: title, body: body, soundDescriptor: soundDescriptor,
            interruptionLevel: interruptionLevel, repeats: true)
        content.userInfo = ["fingerprint": fingerprint]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        return DesiredItem(identifier: identifier, fingerprint: fingerprint, request: request)
    }

    /// Penceredeki dini günler (Diyanet Hicri tarihinden tespit) için tebrik bildirimi.
    /// Kandiller idrak akşamına (idrak gününün eve'si), bayram/gündüz olanlar sabaha kurulur.
    /// `event-key` (`m<hicriAy>d<hicriGün>`) fingerprint'e değil identifier'a girer —
    /// aynı dini gün, farklı Miladi tarihlerde tekrar ederken kararlı kalır; asıl fire
    /// tarihi identifier'daki `<yyyy-MM-dd>` bileşeninden gelir.
    private func religiousItems(
        from schedule: PrayerSchedule, now: Date, cal: Calendar, config: SchedulerConfig
    ) -> [DesiredItem] {
        var out: [DesiredItem] = []
        for day in schedule.days {
            let weekday = cal.component(.weekday, from: day.dayStart)
            guard let holy = ExtraNotifications.holyDay(
                hijriMonth: day.hicriMonth, hijriDay: day.hicriDay, weekday: weekday)
            else { continue }

            // Kandil "gece": idrak akşamı = eşleşen günün bir önceki akşamı (~20:00),
            //   çünkü Hicri gün maghrib'de başlar. Bayram/gündüz: o günün sabahı (~08:00).
            let fire: Date? = holy.isEve
                ? cal.date(byAdding: .hour, value: -4, to: day.dayStart)
                : cal.date(byAdding: .hour, value: 8, to: day.dayStart)
            guard let fire, fire > now else { continue }

            let content = UNMutableNotificationContent()
            let title = holy.name
            let body = holy.greeting
            content.title = title
            content.body = body
            let soundDescriptor = config.silent ? "silent" : config.sound.rawValue
            if let sound = config.sound.unSound(silent: config.silent) {
                content.sound = sound
            }
            let interruptionLevel: UNNotificationInterruptionLevel = .active
            content.interruptionLevel = interruptionLevel

            var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            components.timeZone = cal.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let eventKey = "m\(day.hicriMonth ?? 0)d\(day.hicriDay ?? 0)"
            let dateKey = ExtraNotifications.dateKey(day.dayStart, cal)
            let identifier = "\(Self.v2Prefix)holy.\(eventKey).\(dateKey)"

            let fingerprint = Self.fingerprint(
                components: components, timeZoneIdentifier: cal.timeZone.identifier,
                title: title, body: body, soundDescriptor: soundDescriptor,
                interruptionLevel: interruptionLevel)
            content.userInfo = ["fingerprint": fingerprint]

            out.append(DesiredItem(
                identifier: identifier, fingerprint: fingerprint,
                request: UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
        }
        return out
    }

    /// Sonraki `limit` gün için, belirlenen saatte günlük ayet/dua bildirimi.
    /// Özel günse o güne temalı ayet, değilse anlamlı rotasyon gösterilir. İçerik Hicri
    /// tarihe/özel-güne bağlı olduğundan title+body zaten fingerprint'e girer — kaynak
    /// veri değişirse fingerprint de değişir, `add()` otomatik günceller.
    private func verseItems(
        from schedule: PrayerSchedule, now: Date, cal: Calendar,
        config: SchedulerConfig, limit: Int
    ) -> [DesiredItem] {
        var out: [DesiredItem] = []
        for day in schedule.days.sorted(by: { $0.dayStart < $1.dayStart }) {
            if out.count >= limit { break }
            let weekday = cal.component(.weekday, from: day.dayStart)
            let holy = ExtraNotifications.holyDay(
                hijriMonth: day.hicriMonth, hijriDay: day.hicriDay, weekday: weekday)
            guard let fire = cal.date(bySettingHour: config.dailyVerseHour, minute: 0, second: 0,
                                      of: day.dayStart), fire > now,
                  let verse = ExtraNotifications.verse(on: day.dayStart, calendar: cal, holyDay: holy)
            else { continue }

            let content = UNMutableNotificationContent()
            let title = "Günün Ayeti"
            let body = "\(verse.text) — \(verse.source)"
            content.title = title
            content.body = body
            // En nazik: sessiz, bildirim listesine/kilit ekranına düşer.
            let interruptionLevel: UNNotificationInterruptionLevel = .passive
            content.interruptionLevel = interruptionLevel

            var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            components.timeZone = cal.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let dateKey = ExtraNotifications.dateKey(day.dayStart, cal)
            let identifier = "\(Self.v2Prefix)verse.\(dateKey)"

            let fingerprint = Self.fingerprint(
                components: components, timeZoneIdentifier: cal.timeZone.identifier,
                title: title, body: body, soundDescriptor: "none",
                interruptionLevel: interruptionLevel)
            content.userInfo = ["fingerprint": fingerprint]

            out.append(DesiredItem(
                identifier: identifier, fingerprint: fingerprint,
                request: UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
        }
        return out
    }

    // MARK: - Fingerprint (identifier'da DEĞİL — content.userInfo'da tutulur)

    /// Görünür/duyulur olan HER ŞEYDEN üretilir: tetiklenme anı (saat/dakika/gün/hafta-
    /// günü + timezone + tek-seferlik/repeating) + title/body + ses + interruptionLevel.
    /// Vakit Diyanet verisiyle kayarsa (ID aynı kalsa da) bu değişir → `add()` otomatik
    /// replace eder; alakasız bir ayar değişikliği ise bu ögeyi hiç etkilemez (her istek
    /// türü yalnızca KENDİ ilgili alanlarını geçirir).
    private static func fingerprint(
        components: DateComponents, timeZoneIdentifier: String, title: String, body: String,
        soundDescriptor: String, interruptionLevel: UNNotificationInterruptionLevel, repeats: Bool = false
    ) -> String {
        let parts = [
            String(components.year ?? 0), String(components.month ?? 0), String(components.day ?? 0),
            String(components.hour ?? 0), String(components.minute ?? 0), String(components.weekday ?? 0),
            String(repeats), timeZoneIdentifier, title, body, soundDescriptor,
            String(interruptionLevel.rawValue)
        ]
        return itemFingerprint(parts)
    }

    private static func itemFingerprint(_ parts: [String]) -> String {
        String(stableHash(parts.joined(separator: "|")), radix: 36)
    }

    /// Swift'in `hashValue`'su süreç başına rastgele tuzlandığı için (güvenlik amaçlı)
    /// uygulama yeniden başlatıldığında aynı girdi için farklı sonuç verir — bu da her
    /// launch'ta fingerprint'in gereksiz yere değişmesine yol açardı. FNV-1a basit ve
    /// süreçler arası kararlı.
    private static func stableHash(_ s: String) -> UInt32 {
        var hash: UInt32 = 2166136261
        for byte in s.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return hash
    }
}
