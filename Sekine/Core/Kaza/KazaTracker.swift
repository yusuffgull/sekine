import Foundation

/// Kaza namazı takibi — tamamen yerel, hiçbir yere gönderilmez.
///
/// Model: her vakit için "kalan borç" sayısı (`remaining`). Kullanıcı önce ne kadar
/// kaza namazı borcu olduğunu girer (`addDebt`), sonra kıldıkça düşer (`logCompletion`).
/// Ücretsiz: sayaçlar + seri (streak). Premium: geçmiş istatistik (`recentCompletions`).
///
/// `AppSettings`'e değil ayrı bir sınıfa konmasının nedeni `Store.swift`/`PremiumGate`
/// ile aynı desen: kendi başına test edilebilir, tek sorumluluklu bir mağaza.
@MainActor
final class KazaTracker: ObservableObject {
    /// Güneş bir namaz vakti değildir; kaza kapsamı dışında (bkz. `Prayer.isNotifiable`
    /// ile aynı gerekçe, farklı bir amaç için ayrı tutuldu — ileride birbirinden
    /// bağımsız değişebilirler).
    static let kazaPrayers: [Prayer] = Prayer.ordered.filter { $0 != .sunrise }

    @Published private(set) var remaining: [Prayer: Int] {
        didSet { saveRemaining() }
    }

    /// Tamamlanan HER kaza namazının tarihi (gün çözünürlüğünde, `startOfDay`).
    /// Seri hesaplama ve premium istatistik ("bu hafta kaç kaza kıldınız") için.
    /// Sınırsız büyümesin diye en fazla `maxLogEntries` tutulur (en eskiler atılır) —
    /// bir kullanıcının ömür boyu kaza kaydı bile bu sınırın çok altında kalır, bu
    /// yalnızca teorik bir üst sınır.
    @Published private(set) var completionLog: [Date] {
        didSet { saveLog() }
    }

    private static let maxLogEntries = 2000

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard,
         calendar: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }()) {
        self.defaults = defaults
        self.calendar = calendar
        self.remaining = Self.loadRemaining(defaults)
        self.completionLog = Self.loadLog(defaults)
    }

    /// Toplam kalan kaza (tüm vakitler).
    var totalRemaining: Int { remaining.values.reduce(0, +) }

    func remaining(for prayer: Prayer) -> Int { remaining[prayer] ?? 0 }

    /// Kullanıcı ilk kurulumda/istediğinde borcunu artırır (ör. "500 öğle kazam var").
    func addDebt(_ prayer: Prayer, count: Int = 1) {
        guard count > 0 else { return }
        remaining[prayer, default: 0] += count
    }

    /// Bir kaza namazı kılındığında çağrılır: borç 1 azalır (0'ın altına inmez) ve
    /// bugünün tarihi kayda geçer (seri + istatistik için). Borç zaten 0'sa yine de
    /// kayda geçer — kullanıcı "nafile kaza" da kılmış olabilir, seri bunu saymalı.
    func logCompletion(_ prayer: Prayer) {
        let current = remaining[prayer, default: 0]
        remaining[prayer] = max(0, current - 1)
        completionLog.append(Date())
        if completionLog.count > Self.maxLogEntries {
            completionLog.removeFirst(completionLog.count - Self.maxLogEntries)
        }
    }

    /// Belirli bir vakit için borcu doğrudan ayarlar (ör. kullanıcı ayarlar ekranında
    /// tam sayıyı elden düzeltmek isterse). Negatif değer 0'a sabitlenir.
    func setRemaining(_ prayer: Prayer, to value: Int) {
        remaining[prayer] = max(0, value)
    }

    /// Kaç FARKLI günde en az bir kaza kılınmış, art arda (bugün veya dünden başlayarak
    /// geriye doğru kesintisiz) — klasik "streak" hesabı. `completionLog`'dan türetilir,
    /// ayrıca saklanmaz (tek doğruluk kaynağı log; tutarsızlık riski yok).
    var currentStreak: Int {
        Self.computeStreak(from: completionLog, calendar: calendar, asOf: Date())
    }

    /// Saf, test edilebilir seri hesabı. `asOf` günü kayıtlı DEĞİLSE (bugün henüz kaza
    /// kılınmadıysa) seri "dün"den geriye sayılır — kullanıcı henüz bugünü kaydetmediği
    /// için seriyi anında sıfırlamak cezalandırıcı olur; gün bitene kadar seri korunur.
    nonisolated static func computeStreak(from log: [Date], calendar: Calendar, asOf now: Date) -> Int {
        let days = Set(log.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            // Bugün kaydı yok — dünden başlayarak dene.
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            guard days.contains(cursor) else { return 0 }
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Premium istatistik: son `days` gün içinde kılınan kaza sayısı.
    func completions(inLast days: Int) -> Int {
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return 0 }
        return completionLog.filter { $0 >= cutoff }.count
    }

    #if DEBUG
    /// `-uiTestSeedKaza`: mağaza ekran görüntüsü için örnek borç + son 5 günde tamamlama.
    func seedForUITest() {
        for (prayer, n) in [(Prayer.fajr, 12), (.dhuhr, 30), (.asr, 18), (.maghrib, 7), (.isha, 21)] {
            setRemaining(prayer, to: n)
        }
        completionLog = (0..<5).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
    }
    #endif

    // MARK: - Persistence

    private func saveRemaining() {
        let raw = Dictionary(uniqueKeysWithValues: remaining.map { ($0.key.rawValue, $0.value) })
        defaults.set(raw, forKey: Keys.remaining)
    }

    private func saveLog() {
        let raw = completionLog.map { $0.timeIntervalSince1970 }
        defaults.set(raw, forKey: Keys.log)
    }

    private static func loadRemaining(_ d: UserDefaults) -> [Prayer: Int] {
        let raw = d.dictionary(forKey: Keys.remaining) as? [String: Int] ?? [:]
        var out: [Prayer: Int] = [:]
        for (k, v) in raw {
            if let p = Prayer(rawValue: k) { out[p] = v }
        }
        return out
    }

    private static func loadLog(_ d: UserDefaults) -> [Date] {
        let raw = d.array(forKey: Keys.log) as? [Double] ?? []
        return raw.map { Date(timeIntervalSince1970: $0) }
    }

    private enum Keys {
        static let remaining = "kaza.remaining"
        static let log = "kaza.completionLog"
    }
}
