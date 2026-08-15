import Foundation
import BackgroundTasks

/// Arka plan yenileme: uygulama açılmasa bile bildirim penceresini (64 sınırı)
/// tazeler. Network gerektirmez — cache'ten okur. BGAppRefresh iOS tarafından
/// garanti edilmez; bu yüzden app açılışı ve willPresent tazelemesi de vardır
/// (çok katmanlı güvenilirlik).
enum BackgroundRefresh {
    static let taskIdentifier = "com.sekineapp.sekine.refresh"
    /// Gece/şarj sırasında çalışan uzun görev — İmsak öncesi pencereyi tazeler.
    static let nightlyIdentifier = "com.sekineapp.sekine.nightly"

    static func register() {
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

        let work = Task {
            await rescheduleFromCache()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    /// Cache + kayıtlı ayarlarla bildirimleri yeniden zamanlar (network yok).
    static func rescheduleFromCache() async {
        guard let schedule = PrayerCache.load() else { return }
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

        await RollingScheduler().reschedule(from: schedule, config: config)
    }
}
