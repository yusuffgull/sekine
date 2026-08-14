import Foundation
import BackgroundTasks

/// Arka plan yenileme: uygulama açılmasa bile bildirim penceresini (64 sınırı)
/// tazeler. Network gerektirmez — cache'ten okur. BGAppRefresh iOS tarafından
/// garanti edilmez; bu yüzden app açılışı ve willPresent tazelemesi de vardır
/// (çok katmanlı güvenilirlik).
enum BackgroundRefresh {
    static let taskIdentifier = "com.sekineapp.sekine.refresh"

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier, using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // ~6 saat sonra; iOS gerçek zamanı kendi belirler.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
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
        let config = SchedulerConfig(
            enabledPrayers: enabled,
            sound: sound,
            silent: defaults.bool(forKey: "settings.silent"),
            preReminderMinutes: defaults.object(forKey: "settings.preReminder") as? Int ?? 0,
            breakThroughFocus: defaults.bool(forKey: "settings.breakThroughFocus"))

        await RollingScheduler().reschedule(from: schedule, config: config)
    }
}
