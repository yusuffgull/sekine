import Foundation

/// Watch'ın bağımsız bildirim planlayıcısı. RollingScheduler'ı DEĞİŞTİRMEDEN kullanır —
/// yalnızca ekstra bildirimleri (Cuma/kandil/günlük-ayet) kapatır. Gerekçe: bu bildirimlerin
/// kimlikleri konum değil ayar bazlı türüyor (`friday-weekly`, `holy-<date>`, `verse-<date>`);
/// iki cihazın ayarları senkron değilse dedup garanti edilemez ve kullanıcı çift bildirim
/// alabilir. Namaz vakti bildirimleri ise konum bazlı deterministik kimlik kullanıyor
/// (`RollingScheduler.makeRequest`), bu yüzden telefonla aynı konumda dedup güvenlidir.
enum WatchNotificationScheduler {
    @MainActor
    static func reschedule(settings: AppSettings) async {
        guard let schedule = PrayerCache.load() else { return }
        let enabled = Set(Prayer.ordered.filter { $0.isNotifiable && !settings.disabledPrayers.contains($0) })
        let config = SchedulerConfig(
            enabledPrayers: enabled,
            sound: NotificationSound(rawValue: settings.notificationSound) ?? .default,
            perPrayerSounds: settings.perPrayerSounds,
            silent: settings.silentNotifications,
            preReminderMinutes: settings.preReminderMinutes,
            breakThroughFocus: settings.breakThroughFocus,
            fridayReminder: false,
            fridayReminderHour: settings.fridayReminderHour,
            specialDayGreetings: false,
            dailyVerse: false,
            dailyVerseHour: settings.dailyVerseHour)
        await RollingScheduler().reschedule(from: schedule, config: config)
    }
}
