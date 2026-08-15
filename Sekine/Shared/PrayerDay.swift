import Foundation

/// Bir güne ait tek bir vakit (mutlak an olarak saklanır → timezone hatası olmaz).
struct PrayerTime: Codable, Hashable, Identifiable, Sendable {
    let prayer: Prayer
    let date: Date
    var id: String { prayer.rawValue + "-" + String(date.timeIntervalSince1970) }
}

/// Bir güne ait tüm vakitler.
struct PrayerDay: Codable, Hashable, Identifiable, Sendable {
    /// O günün yerel 00:00'ı (gün eşleştirmesi için).
    let dayStart: Date
    let times: [PrayerTime]
    /// Diyanet resmi Hicri tarihi, ör. "26 Safer 1448" (yalnızca Diyanet kaynağında).
    let hicriDate: String?
    /// Hicri ay (1–12) ve gün (1–30) — dini günleri tespit etmek için (Diyanet kaynağı).
    let hicriMonth: Int?
    let hicriDay: Int?
    /// Güneş-kıble hizalanma anı (Diyanet "Kıble Saati"); kıbleyi güneşle bulmak için.
    let qiblaTime: Date?

    // Optional alanlar → eski cache (bu alanlar yokken) geriye dönük uyumlu decode olur.
    init(dayStart: Date, times: [PrayerTime], hicriDate: String? = nil,
         hicriMonth: Int? = nil, hicriDay: Int? = nil, qiblaTime: Date? = nil) {
        self.dayStart = dayStart
        self.times = times
        self.hicriDate = hicriDate
        self.hicriMonth = hicriMonth
        self.hicriDay = hicriDay
        self.qiblaTime = qiblaTime
    }

    var id: Date { dayStart }

    func time(for prayer: Prayer) -> Date? {
        times.first(where: { $0.prayer == prayer })?.date
    }

    /// Verilen ana göre bu gün içindeki bir sonraki vakit (yoksa nil).
    func nextTime(after now: Date) -> PrayerTime? {
        times.filter { $0.date > now }.min(by: { $0.date < $1.date })
    }
}

/// Cache'lenen tam plan: konum + günlerin listesi.
struct PrayerSchedule: Codable, Sendable {
    let placeName: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
    let source: String        // "aladhan-13" | "local-adhan"
    let fetchedAt: Date
    let days: [PrayerDay]

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    func day(containing date: Date) -> PrayerDay? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let target = cal.startOfDay(for: date)
        return days.first { cal.isDate($0.dayStart, inSameDayAs: target) }
    }

    /// Şu ana göre gelecek ilk vakit (gün sınırlarını aşarak arar).
    func nextTime(after now: Date) -> PrayerTime? {
        days.flatMap(\.times).filter { $0.date > now }.min(by: { $0.date < $1.date })
    }

    /// Şu ana göre en son geçmiş vakit (aktif vakit göstergesi için).
    func currentTime(at now: Date) -> PrayerTime? {
        days.flatMap(\.times).filter { $0.date <= now }.max(by: { $0.date < $1.date })
    }
}
