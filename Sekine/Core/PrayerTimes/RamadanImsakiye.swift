import Foundation

/// Ramazan imsakiyesi: her gün için sahur sonu (imsak) ve iftar (akşam). Saf, UI'sız.
///
/// Güven düzeyleri AYRI tutulur (bkz. docs/ramadan-2027-plan.md):
/// - `isDateEstimated`: gün numarası Diyanet'in hicri verisinden değil, Umm al-Qura tahmininden
///   (±1 gün sapabilir; ay başı/sonunda `isBoundary`).
/// - `isTimeApproximate`: vakit çevrimiçi yaklaşık takvimden (güvenlik paylı), Diyanet değil.
struct RamadanImsakiye: Equatable {
    struct Row: Equatable, Identifiable {
        let dayNumber: Int
        let date: Date
        let timeZone: TimeZone
        let fajr: Date
        let maghrib: Date
        let isDateEstimated: Bool
        let isTimeApproximate: Bool
        let isBoundary: Bool
        var id: Date { date }
    }

    let rows: [Row]

    var hasEstimates: Bool { rows.contains { $0.isDateEstimated || $0.isTimeApproximate } }

    static func build(from entries: [MonthlyEntry]) -> RamadanImsakiye {
        let sorted = entries.sorted { $0.day.dayStart < $1.day.dayStart }

        // 1) Diyanet'in KESİN Ramazan günleri.
        var rows: [Row] = sorted.compactMap { e in
            guard e.day.hicriMonth == RamadanInfo.ramadanHicriMonth,
                  let n = e.day.hicriDay,
                  let fajr = e.day.time(for: .fajr),
                  let maghrib = e.day.time(for: .maghrib) else { return nil }
            return Row(dayNumber: n, date: e.day.dayStart, timeZone: e.timeZone,
                       fajr: fajr, maghrib: maghrib,
                       isDateEstimated: false, isTimeApproximate: e.isApproximate, isBoundary: false)
        }

        // 2) Hicri verisi olmayan günler: Umm al-Qura tahmini. Kesin satır varsa tahmin
        //    yalnızca ONLARIN SONRASINDAKİ günlere uygulanır ve numaralama kesin satırdan
        //    devam eder (aynı ekranda çelişen gün numarası olmasın).
        let lastCertain = rows.last
        let candidates = sorted.filter { e in
            e.day.hicriMonth == nil
                && (lastCertain.map { e.day.dayStart > $0.date } ?? true)
        }
        var nextNumber = (lastCertain?.dayNumber ?? 0) + 1
        for e in candidates {
            guard let est = HijriEstimate.estimate(for: e.day.dayStart.addingTimeInterval(12 * 3600),
                                                   timeZone: e.timeZone),
                  est.month == RamadanInfo.ramadanHicriMonth,
                  let fajr = e.day.time(for: .fajr),
                  let maghrib = e.day.time(for: .maghrib) else { continue }
            let number = lastCertain == nil ? est.day : nextNumber
            guard number <= 30 else { break }
            rows.append(Row(dayNumber: number, date: e.day.dayStart, timeZone: e.timeZone,
                            fajr: fajr, maghrib: maghrib,
                            isDateEstimated: true, isTimeApproximate: e.isApproximate,
                            isBoundary: est.isBoundary))
            nextNumber += 1
        }
        return RamadanImsakiye(rows: rows)
    }
}
