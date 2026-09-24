import Foundation

/// Oruç günü takibi — tamamen yerel, hiçbir yere gönderilmez. Tutulan günler
/// `yyyy-MM-dd` anahtarlarıyla (konumun saat diliminde) saklanır. Ramazan ilerlemesi
/// "bugünün Ramazan gün numarasından" türetilir (bkz. `RamadanInfo`): Ramazan başlangıcı
/// = bugün − (gün−1), böylece hicri yıl ayrıştırmaya ya da sabit tarih tablosuna
/// ihtiyaç kalmaz.
@MainActor
final class FastingTracker: ObservableObject {
    @Published private(set) var fastedDays: Set<String> {
        didSet { defaults.set(Array(fastedDays), forKey: Keys.days) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard) {
        self.defaults = defaults
        self.fastedDays = Set(defaults.stringArray(forKey: Keys.days) ?? [])
    }

    nonisolated static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func isFasted(_ date: Date, calendar: Calendar) -> Bool {
        fastedDays.contains(Self.key(for: date, calendar: calendar))
    }

    func toggle(_ date: Date, calendar: Calendar) {
        let k = Self.key(for: date, calendar: calendar)
        if fastedDays.contains(k) { fastedDays.remove(k) } else { fastedDays.insert(k) }
    }

    /// Bugün Ramazan'ın `dayNumber`. günüyse, bu Ramazan'da (1. günden bugüne dahil)
    /// tutulan gün sayısı. Saf hesap → `nonisolated static`, doğrudan test edilir.
    nonisolated static func fastedCount(
        in fasted: Set<String>, today: Date, dayNumber: Int, calendar: Calendar
    ) -> Int {
        guard dayNumber >= 1 else { return 0 }
        var count = 0
        for offset in 0..<dayNumber {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if fasted.contains(key(for: d, calendar: calendar)) { count += 1 }
        }
        return count
    }

    func fastedCount(today: Date, dayNumber: Int, calendar: Calendar) -> Int {
        Self.fastedCount(in: fastedDays, today: today, dayNumber: dayNumber, calendar: calendar)
    }

    private enum Keys { static let days = "fasting.days" }
}
