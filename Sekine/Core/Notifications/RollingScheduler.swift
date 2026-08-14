import Foundation
import UserNotifications

struct SchedulerConfig {
    var enabledPrayers: Set<Prayer>
    var sound: NotificationSound
    var silent: Bool
    var preReminderMinutes: Int
    /// Kullanıcı onayıyla Odak/Uyku/DND'yi delme (opt-in).
    var breakThroughFocus: Bool
}

/// iOS aynı anda EN FAZLA 64 zamanlanmış yerel bildirim tutar. Rakiplerin
/// "bildirimler bir süre sonra duruyor" hatası, bu pencereyi tazelememelerinden
/// kaynaklanır. RollingScheduler her tetiklenişte gelecekteki ilk N vakti yeniden
/// zamanlar; app açılışı, arka plan görevi ve bildirim tetiklenişi bunu tazeler.
struct RollingScheduler {
    /// 64 sınırının altında güvenli tavan (pre-reminder ile birlikte).
    static let maxNotifications = 60

    private let center = UNUserNotificationCenter.current()

    func reschedule(from schedule: PrayerSchedule, config: SchedulerConfig) async {
        center.removeAllPendingNotificationRequests()

        guard !config.enabledPrayers.isEmpty else { return }

        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone

        // Gelecekteki tüm bildirilebilir vakitleri, zamana göre sıralı topla.
        let upcoming = schedule.days
            .flatMap(\.times)
            .filter { $0.date > now && config.enabledPrayers.contains($0.prayer) }
            .sorted { $0.date < $1.date }

        var requests: [UNNotificationRequest] = []
        for time in upcoming {
            if requests.count >= Self.maxNotifications { break }

            // Ana vakit bildirimi
            requests.append(makeRequest(
                for: time, calendar: cal, config: config, isPreReminder: false))

            // Vakitten X dakika önce hatırlatma (isteğe bağlı)
            if config.preReminderMinutes > 0,
               requests.count < Self.maxNotifications,
               let preDate = cal.date(byAdding: .minute,
                                      value: -config.preReminderMinutes, to: time.date),
               preDate > now {
                requests.append(makeRequest(
                    for: PrayerTime(prayer: time.prayer, date: preDate),
                    calendar: cal, config: config, isPreReminder: true))
            }
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    /// Bir bildirim isteği üretir (mutlak tarihten date components ile, tekrar yok).
    private func makeRequest(
        for time: PrayerTime,
        calendar cal: Calendar,
        config: SchedulerConfig,
        isPreReminder: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        if isPreReminder {
            content.title = "\(time.prayer.displayName) yaklaşıyor"
            content.body = "\(time.prayer.displayName) vaktine \(config.preReminderMinutes) dakika kaldı."
        } else {
            content.title = "\(time.prayer.displayName) Vakti"
            content.body = bodyText(for: time.prayer)
        }
        if let sound = config.sound.unSound(silent: config.silent) {
            content.sound = sound
        }
        // Opt-in: yalnızca kullanıcı onay verdiyse Odak/Uyku/DND'yi del.
        content.interruptionLevel = config.breakThroughFocus ? .timeSensitive : .active

        let components = cal.dateComponents(
            [.year, .month, .day, .hour, .minute], from: time.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = "\(time.prayer.rawValue)-\(isPreReminder ? "pre" : "main")-\(Int(time.date.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
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
}
