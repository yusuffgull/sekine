import Foundation

/// Sabit Hicri tarihli dini gün. Diyanet feed'inin Hicri ayı+günüyle eşleşir → yıllık
/// bakım/güncelleme gerekmez, her zaman Diyanet takvimiyle birebir.
/// `hijriDay == 0` = Regaib işareti (Recep'in ilk Cuması, koda gömülü kuralla).
/// `eve == true` kandil (idrak akşamı), `false` bayram/gündüz. `verse` varsa o gün
/// "günün ayeti" bu olur (bağlam duyarlı).
struct HolyDay: Decodable, Hashable {
    let hijriMonth: Int
    let hijriDay: Int
    let name: String
    let greeting: String
    let eve: Bool?
    let verse: String?
    let verseSource: String?

    var isEve: Bool { eve ?? true }
}

/// Normal günlerde gösterilecek anlamlı ayet/dua (rotasyon).
struct DailyVerse: Decodable, Hashable {
    let text: String
    let source: String
}

/// Ek bildirim içeriğinin bundle'lı, saf (ağsız) kaynağı.
enum ExtraNotifications {
    /// Recep = 7. Hicri ay (Regaib bu ayın ilk Cumasında).
    static let recepMonth = 7

    static let holyDays: [HolyDay] = load("HolyDays")
    static let dailyVerses: [DailyVerse] = load("DailyVerses")

    /// Verilen günün Hicri ay/gün (+ Regaib için hafta günü) bilgisiyle dini günü döner.
    /// weekday: Gregoryen (Pazar=1 … Cuma=6).
    static func holyDay(hijriMonth month: Int?, hijriDay day: Int?, weekday: Int?) -> HolyDay? {
        guard let month, let day else { return nil }
        if let fixed = holyDays.first(where: { $0.hijriMonth == month && $0.hijriDay == day }) {
            return fixed
        }
        // Regaib: Recep'in ilk Cuması (gün ≤ 7 ve Cuma).
        if month == recepMonth, day <= 7, weekday == 6,
           let regaib = holyDays.first(where: { $0.hijriMonth == recepMonth && $0.hijriDay == 0 }) {
            return regaib
        }
        return nil
    }

    /// Günün ayeti: özel günse o güne temalı ayet; değilse anlamlı rotasyon (yıl-günü index'i).
    static func verse(on date: Date, calendar cal: Calendar, holyDay: HolyDay?) -> DailyVerse? {
        if let holyDay, let text = holyDay.verse, let source = holyDay.verseSource {
            return DailyVerse(text: text, source: source)
        }
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
