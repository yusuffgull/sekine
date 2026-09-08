import Foundation
import BackgroundTasks

/// Arka plan yenileme: uygulama açılmasa bile bildirim penceresini (64 sınırı)
/// tazeler. Network gerektirmez — cache'ten okur. BGAppRefresh iOS tarafından
/// garanti edilmez; bu yüzden app açılışı ve willPresent tazelemesi de vardır
/// (çok katmanlı güvenilirlik).
///
/// **Kendi `RollingScheduler` instance'ını YARATMAZ.** Composition root
/// `SekineApp.init()`'te yaratılan TEK kanonik instance, `AppDelegate` üzerinden
/// `register(scheduler:)` ile buraya enjekte edilir — aksi halde `PrayerTimeStore`'un
/// tuttuğu instance ile burası aynı `UNUserNotificationCenter`'a eşzamanlı, izole
/// edilmemiş iki ayrı actor'dan dokunurdu (bkz. `RollingScheduler` dokümantasyonu).
enum BackgroundRefresh {
    static let taskIdentifier = "com.sekineapp.sekine.refresh"
    /// Gece/şarj sırasında çalışan uzun görev — İmsak öncesi pencereyi tazeler.
    static let nightlyIdentifier = "com.sekineapp.sekine.nightly"

    /// `internal` (default) erişim, bilinçli: `SekineTests` (`@testable import`) enjeksiyon
    /// başarısızlığı senaryosunu (composition root scheduler'ı hiç `register` etmemiş)
    /// simüle edebilmek için bunu `nil`'e set edip geri yükleyebilmeli.
    static var scheduler: RollingScheduler?

    /// `AppDelegate.application(_:didFinishLaunchingWithOptions:)` içinden, composition
    /// root'un (`SekineApp.init()`) yarattığı kanonik `RollingScheduler` ile çağrılır.
    static func register(scheduler: RollingScheduler) {
        self.scheduler = scheduler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier, using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: nightlyIdentifier, using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handle(processingTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // ~6 saat sonra; iOS gerçek zamanı kendi belirler.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)

        // Gece görevi: ağ/güç şartı yok → iOS uygun bir zamanda (genelde şarjda) çalıştırır.
        let nightly = BGProcessingTaskRequest(identifier: nightlyIdentifier)
        nightly.requiresNetworkConnectivity = false
        nightly.requiresExternalPower = false
        nightly.earliestBeginDate = Date(timeIntervalSinceNow: 8 * 3600)
        try? BGTaskScheduler.shared.submit(nightly)
    }

    private static func handle(_ task: BGTask) {
        schedule() // bir sonrakini kuyruğa al

        // Bu BGTask koşusuna ÖZEL token — `expirationHandler` bunu `markExpired(_:)`'a
        // verir, böylece SADECE bu koşu etkilenir. Global bir bayrak olsaydı, bu iş bitip
        // sıradaki (bambaşka bir BGTask'e ait) iş başladıktan SONRA gelen gecikmiş bir
        // expire sinyali o YENİ işi de expired sayardı (bkz. `RollingScheduler.RescheduleToken`
        // dokümantasyonu).
        let token = RollingScheduler.RescheduleToken()

        let work = Task {
            let result = await rescheduleFromCache(token: token)
            // `deferred`/`failed` varken OS'a "success:true" DEMEYİZ — kısmi/tekrar
            // deneme sinyali böylece iOS'un kendi retry/backoff davranışına yansır.
            task.setTaskCompleted(success: result.isFullSuccess)
        }
        // `work.cancel()` TEK BAŞINA yetmez: `RollingScheduler` bir actor, cancellation
        // onun içindeki `await` zincirini (drainTask, in-flight `add()` döngüleri) KESMEZ
        // — is arka planda sessizce devam edebilir ve `setTaskCompleted` BGTask'in
        // sözleşme gereği beklediği makul sürede hiç çağrılmayabilir. Bu yüzden actor'a
        // AYRICA açık bir `markExpired(token:)` sinyali gönderilir: scheduler mevcut işi
        // yarım bırakmadan tamamlar ama bir sonraki elemana geçmeden önce erken durur,
        // `work` Task'i böylece kısa sürede döner ve `setTaskCompleted(false)` çağrılır.
        task.expirationHandler = {
            work.cancel()
            // `markExpired` artık actor-izoleli, senkron bir metot (bkz. `RollingScheduler`
            // dokümantasyonu) — bu closure senkron olduğu için tek bir `Task` ile doğrudan
            // `await` edilir; RollingScheduler içeride AYRICA bir fire-and-forget Task
            // spawn etmez (önceki token sızıntısı riskinin kaynağı buydu).
            Task { await scheduler?.markExpired(token) }
        }
    }

    /// Cache + kayıtlı ayarlarla bildirimleri yeniden zamanlar (network yok).
    @discardableResult
    static func rescheduleFromCache(
        token: RollingScheduler.RescheduleToken = RollingScheduler.RescheduleToken()
    ) async -> RescheduleResult {
        guard let scheduler else {
            print("BackgroundRefresh: scheduler henüz enjekte edilmedi (register(scheduler:) çağrılmamış).")
            // P1 fix #3: `failed:0, deferred:0` döndürmek `isFullSuccess == true` demekti —
            // composition root'ta enjeksiyon başarısız olduğunda (scheduler nil) OS'a
            // YANLIŞLIKLA "başarı" raporlanırdı. `failed: 1` ile bu durumu açıkça
            // başarısızlık say; bir sonraki BGTask tetiklenişinde tekrar denenecek.
            return RescheduleResult(requested: 0, added: 0, removed: 0, failed: 1, deferred: 0)
        }
        guard let schedule = PrayerCache.load() else {
            return RescheduleResult(requested: 0, added: 0, removed: 0, failed: 0, deferred: 0)
        }
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

        let disabledRaw = defaults.stringArray(forKey: "settings.disabledPrayers") ?? []
        let disabled = Set(disabledRaw.compactMap(Prayer.init(rawValue:)))
        let enabled = Set(Prayer.ordered.filter { $0.isNotifiable && !disabled.contains($0) })

        let sound = NotificationSound(rawValue: defaults.string(forKey: "settings.sound") ?? "") ?? .default
        var perPrayer: [Prayer: NotificationSound] = [:]
        if let raw = defaults.dictionary(forKey: "settings.perPrayerSounds") as? [String: String] {
            for (k, v) in raw {
                if let p = Prayer(rawValue: k), let s = NotificationSound(rawValue: v) { perPrayer[p] = s }
            }
        }
        func flag(_ key: String, default def: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? def
        }
        let config = SchedulerConfig(
            enabledPrayers: enabled,
            sound: sound,
            perPrayerSounds: perPrayer,
            silent: defaults.bool(forKey: "settings.silent"),
            preReminderMinutes: defaults.object(forKey: "settings.preReminder") as? Int ?? 0,
            breakThroughFocus: defaults.bool(forKey: "settings.breakThroughFocus"),
            fridayReminder: flag("settings.fridayReminder", default: true),
            fridayReminderHour: defaults.object(forKey: "settings.fridayReminderHour") as? Int ?? 9,
            specialDayGreetings: flag("settings.specialDayGreetings", default: true),
            dailyVerse: flag("settings.dailyVerse", default: true),
            dailyVerseHour: defaults.object(forKey: "settings.dailyVerseHour") as? Int ?? 8)

        let result = await scheduler.reschedule(from: schedule, config: config, token: token)
        if !result.isFullSuccess {
            print("BackgroundRefresh: reschedule kısmen başarısız — istenen \(result.requested), " +
                  "eklendi \(result.added), başarısız \(result.failed), ertelendi \(result.deferred). " +
                  "Bir sonraki tetiklenişte tekrar denenecek.")
        }
        return result
    }
}
