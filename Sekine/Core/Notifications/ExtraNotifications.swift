import Foundation

/// Diyanet resmi dini günü (idrak günü). `date` = yyyy-MM-dd (o günün akşamına tebrik kurulur).
struct ReligiousDay: Decodable, Hashable {
    let date: String
    let name: String
    let greeting: String
}

/// Günlük ayet/dua içeriği (Diyanet meali / bilinen kısa dua). `source` = referans.
struct DailyVerse: Decodable, Hashable {
    let text: String
    let source: String
}

/// Ek bildirim içeriğinin bundle'lı kaynağı (dini günler + günlük ayet/dua).
/// Saf/ağsız → hem app hem widget/BG tarafında, hem de birim testinde kullanılabilir.
enum ExtraNotifications {
    static let religiousDays: [String: ReligiousDay] = {
        let list: [ReligiousDay] = load("ReligiousDays")
        return Dictionary(list.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
    }()

    static let dailyVerses: [DailyVerse] = load("DailyVerses")

    /// Verilen güne denk gelen dini gün (varsa).
    static func religiousDay(on date: Date, calendar cal: Calendar) -> ReligiousDay? {
        religiousDays[dateKey(date, cal)]
    }

    /// Günün ayet/dua içeriği (yıl-günü index'iyle döner → her gün değişir).
    static func verse(on date: Date, calendar cal: Calendar) -> DailyVerse? {
        guard !dailyVerses.isEmpty else { return nil }
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        return dailyVerses[(dayOfYear - 1) % dailyVerses.count]
    }

    // MARK: - Yardımcılar

    static func dateKey(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func load<T: Decodable>(_ resource: String) -> [T] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data)
        else { return [] }
        return decoded
    }
}
