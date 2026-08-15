import Foundation
import UserNotifications

struct SchedulerConfig {
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

/// iOS aynı anda EN FAZLA 64 zamanlanmış yerel bildirim tutar. Rakiplerin
/// "bildirimler bir süre sonra duruyor" hatası, bu pencereyi tazelememelerinden
/// kaynaklanır. RollingScheduler her tetiklenişte gelecekteki ilk N vakti yeniden
/// zamanlar; app açılışı, arka plan görevi ve bildirim tetiklenişi bunu tazeler.
///
/// Bütçe önceliği (60 slot): Cuma (repeating) → kandil/bayram → ana vakitler →
/// günlük ayet → ön-hatırlatma. Ana vakitler ön-hatırlatmadan önce zamanlanır ki
/// çekirdek kapsam (gün sayısı) ekstralar yüzünden azalmasın.
struct RollingScheduler {
    /// 64 sınırının altında güvenli tavan.
    static let maxNotifications = 60
    static let dailyVerseHorizon = 7

    private let center = UNUserNotificationCenter.current()

    func reschedule(from schedule: PrayerSchedule, config: SchedulerConfig) async {
        center.removeAllPendingNotificationRequests()

        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        let cap = Self.maxNotifications

        var requests: [UNNotificationRequest] = []

        // 1) Cuma hatırlatması — haftalık repeating (1 slot, pencere kurusa da gelir).
        if config.fridayReminder {
            requests.append(fridayRequest(config: config))
        }

        // 2) Kandil/bayram tebrikleri — penceredeki gelecekteki günler (nadir).
        if config.specialDayGreetings {
            for req in religiousRequests(from: schedule, now: now, cal: cal, config: config) {
                if requests.count >= cap { break }
                requests.append(req)
            }
        }

        // Ana vakit adayları (kronolojik).
        let mains = schedule.days.flatMap(\.times)
            .filter { $0.date > now && config.enabledPrayers.contains($0.prayer) }
            .sorted { $0.date < $1.date }

        // Günlük ayet/dua adayları (sınırlı ufuk).
        let verseReqs = config.dailyVerse
            ? verseRequests(from: schedule, now: now, cal: cal, config: config, limit: Self.dailyVerseHorizon)
            : []

        // 3) Ana vakitler (öncelik). Ayet + bir miktar ön-hatırlatma için yer ayır.
        let preReserve = config.preReminderMinutes > 0 ? 10 : 0
        let mainsBudget = max(0, cap - requests.count - verseReqs.count - preReserve)
        var scheduledMains: [PrayerTime] = []
        for t in mains {
            if scheduledMains.count >= mainsBudget || requests.count >= cap { break }
            requests.append(makeRequest(for: t, calendar: cal, config: config, isPreReminder: false))
            scheduledMains.append(t)
        }

        // 4) Günlük ayet/dua.
        for req in verseReqs {
            if requests.count >= cap { break }
            requests.append(req)
        }

        // 5) Ön-hatırlatma (kalan bütçe; yalnızca zamanlanmış ana vakitler için, en yakından).
        if config.preReminderMinutes > 0 {
            for t in scheduledMains {
                if requests.count >= cap { break }
                if let preDate = cal.date(byAdding: .minute, value: -config.preReminderMinutes, to: t.date),
                   preDate > now {
                    requests.append(makeRequest(
                        for: PrayerTime(prayer: t.prayer, date: preDate),
                        calendar: cal, config: config, isPreReminder: true))
                }
            }
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    // MARK: - Ana vakit bildirimi

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
        let prayerSound = config.perPrayerSounds[time.prayer] ?? config.sound
        if let sound = prayerSound.unSound(silent: config.silent) {
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

    // MARK: - Ek hatırlatmalar

    /// Cuma günü, haftalık tekrarlayan tek bildirim (kalıcı; pencereden bağımsız).
    private func fridayRequest(config: SchedulerConfig) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Cuma Mübarek Olsun"
        content.body = "Kehf suresini okumayı ve salavât-ı şerifeyi unutmayın."
        if let sound = config.sound.unSound(silent: config.silent) {
            content.sound = sound
        }
        content.interruptionLevel = .active

        var comps = DateComponents()
        comps.weekday = 6 // Cuma (Gregoryen: Pazar=1 … Cuma=6)
        comps.hour = config.fridayReminderHour
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        return UNNotificationRequest(identifier: "friday-weekly", content: content, trigger: trigger)
    }

    /// Penceredeki dini günler (Diyanet Hicri tarihinden tespit) için tebrik bildirimi.
    /// Kandiller idrak akşamına (idrak gününün eve'si), bayram/gündüz olanlar sabaha kurulur.
    private func religiousRequests(
        from schedule: PrayerSchedule, now: Date, cal: Calendar, config: SchedulerConfig
    ) -> [UNNotificationRequest] {
        var out: [UNNotificationRequest] = []
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
            content.title = holy.name
            content.body = holy.greeting
            if let sound = config.sound.unSound(silent: config.silent) {
                content.sound = sound
            }
            content.interruptionLevel = .active

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            out.append(UNNotificationRequest(
                identifier: "holy-\(ExtraNotifications.dateKey(day.dayStart, cal))",
                content: content, trigger: trigger))
        }
        return out
    }

    /// Sonraki `limit` gün için, belirlenen saatte günlük ayet/dua bildirimi.
    /// Özel günse o güne temalı ayet, değilse anlamlı rotasyon gösterilir.
    private func verseRequests(
        from schedule: PrayerSchedule, now: Date, cal: Calendar,
        config: SchedulerConfig, limit: Int
    ) -> [UNNotificationRequest] {
        var out: [UNNotificationRequest] = []
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
            content.title = "Günün Ayeti"
            content.body = "\(verse.text) — \(verse.source)"
            // En nazik: sessiz, bildirim listesine/kilit ekranına düşer.
            content.interruptionLevel = .passive

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            out.append(UNNotificationRequest(
                identifier: "verse-\(ExtraNotifications.dateKey(day.dayStart, cal))",
                content: content, trigger: trigger))
        }
        return out
    }
}
