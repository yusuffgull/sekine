import Foundation

/// App Store puan isteme politikası (yalnızca iOS uygulaması).
///
/// Kural: kullanıcı en az `minOpens` kez açmış VE en az `minActiveDays` FARKLI günde kullanmış
/// olmalı (aynı gün 5 açılış "düzenli kullanım" sayılmaz); sürüm başına en fazla bir kez sorulur.
/// Olumlu bir anın hemen ardından (ör. tesbih turu bitince) bu eşikle sorulur; böyle bir an hiç
/// yaşanmayan kullanıcılar için `fallbackActiveDays` farklı günden sonra açılışta sorulur.
struct ReviewPrompt {
    static let minOpens = 5
    static let minActiveDays = 3
    static let fallbackActiveDays = 7

    private let defaults: UserDefaults
    private let openCountKey = "growth.significantOpenCount"
    private let activeDaysKey = "growth.activeDays"
    private let askedVersionKey = "growth.reviewAskedVersion"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var openCount: Int { defaults.integer(forKey: openCountKey) }
    var activeDayCount: Int { (defaults.stringArray(forKey: activeDaysKey) ?? []).count }

    /// Her uygulama açılışında çağrılır.
    func recordOpen(now: Date = Date(), calendar: Calendar = .current) {
        defaults.set(openCount + 1, forKey: openCountKey)
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        var days = defaults.stringArray(forKey: activeDaysKey) ?? []
        if !days.contains(key) {
            days.append(key)
            defaults.set(Array(days.suffix(60)), forKey: activeDaysKey)
        }
    }

    /// `positiveMoment`: çağıran az önce olumlu bir şey yaşandığını (tur bitti vb.) söylüyor.
    func shouldAsk(version: String, positiveMoment: Bool) -> Bool {
        guard defaults.string(forKey: askedVersionKey) != version else { return false }
        guard openCount >= Self.minOpens else { return false }
        let needed = positiveMoment ? Self.minActiveDays : Self.fallbackActiveDays
        return activeDayCount >= needed
    }

    /// Yalnızca gerçekten sorduğumuzda yazılır; atladıysak sonraki fırsatta tekrar denenebilsin.
    func markAsked(version: String) { defaults.set(version, forKey: askedVersionKey) }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
