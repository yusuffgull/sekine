import Foundation

/// Diyanet'in hicri verisi olmayan kaynaklarda (yurtdışı, Aladhan, yerel hesap) hicri günün
/// TAHMİNİ. Bilinçli olarak `PrayerDay.hicriMonth/hicriDay` alanlarına YAZILMAZ: o alanlar
/// "Diyanet kesin" anlamında kalır ve kandil/bayram bildirimleri, oruç takibi, paylaşım kartı
/// onları kesin sayar. Tahmin (Umm al-Qura) gerçek ilandan ±1 gün sapabilir; tüketiciler
/// bunu etiketlemek ve sınır günlerinde kesin davranış (bildirim vb.) üretmemekle yükümlüdür.
struct HijriEstimate: Equatable {
    let month: Int
    let day: Int
    let year: Int

    /// Bir ay/gün için tahminin güven bandı: ay başı/sonu ±1 gün sapabilir.
    /// `isBoundary`: tahmin ayın ilk/son 1 günündeyse true — kesin bir yargı verilmemeli.
    var isBoundary: Bool { day <= 1 || day >= 29 }

    /// `date`'in `timeZone`'daki takvim gününe karşılık gelen Umm al-Qura hicri tarihi.
    static func estimate(for date: Date, timeZone: TimeZone) -> HijriEstimate? {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return HijriEstimate(month: m, day: d, year: y)
    }
}
