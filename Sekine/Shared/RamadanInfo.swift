import Foundation

/// Ramazan modu için saf (UI'sız, ağsız) hesap. Ramazan'ı TARİH TABLOSUNDAN değil,
/// Diyanet'in kendi hicri verisinden (`PrayerDay.hicriMonth == 9`) tanır — böylece
/// ay başı/sonu Diyanet ilanıyla kayarsa (ru'yet) bu da otomatik doğru kalır ve hiçbir
/// yerde elle girilmiş bir Ramazan tarihi yoktur. Hicri veri yalnızca Diyanet
/// kaynağında dolu (Aladhan/yerel fallback'te `nil`) → o durumlarda Ramazan modu
/// SESSİZCE kapalı kalır, asla tahmin edilmez.
struct RamadanInfo: Equatable {
    static let ramadanHicriMonth = 9

    enum Phase: Equatable {
        /// Oruç sürüyor: hedef akşam (iftar) vakti.
        case untilIftar
        /// Oruç dışı (gece): hedef bir sonraki imsak (sahurun bitişi).
        case untilSahurEnd
    }

    /// Ramazan'ın kaçıncı günü (1–30), Diyanet'in hicri gününden.
    let dayNumber: Int
    let phase: Phase
    let target: Date

    /// `now` Ramazan'daysa geri sayım bilgisi; değilse (ya da güvenle hesaplanamıyorsa) nil.
    /// Hesaplanamayan durumlar: bugün planda yok, hicri veri yok, akşamdan sonra ertesi
    /// gün planda yok — hepsinde YANLIŞ bir sayı göstermek yerine nil döner.
    static func current(schedule: PrayerSchedule, now: Date) -> RamadanInfo? {
        guard let today = schedule.day(containing: now),
              today.hicriMonth == ramadanHicriMonth,
              let hicriDay = today.hicriDay,
              let fajr = today.time(for: .fajr),
              let maghrib = today.time(for: .maghrib)
        else { return nil }

        if now < fajr {
            return RamadanInfo(dayNumber: hicriDay, phase: .untilSahurEnd, target: fajr)
        }
        if now < maghrib {
            return RamadanInfo(dayNumber: hicriDay, phase: .untilIftar, target: maghrib)
        }
        // İftardan sonra: bir sonraki hedef ERTESİ günün imsağı. Ertesi gün planda
        // yoksa (pencere sonu) bilgi verme.
        let later: [PrayerDay] = schedule.days.filter { $0.dayStart > today.dayStart }
        guard let tomorrow = later.min(by: { $0.dayStart < $1.dayStart }),
              let nextFajr = tomorrow.time(for: .fajr)
        else { return nil }
        return RamadanInfo(dayNumber: hicriDay, phase: .untilSahurEnd, target: nextFajr)
    }

    /// Ramazan henüz başlamadıysa, planda görünen ilk Ramazan gününe kaç gün kaldığı
    /// (yarın = 1). Bugün zaten Ramazan'daysa ya da planda Ramazan günü yoksa nil.
    /// Yalnızca yüklü pencere (~32 gün) içinde bakabilir — pencere dışı için nil.
    static func daysUntilStart(schedule: PrayerSchedule, now: Date) -> Int? {
        guard let today = schedule.day(containing: now),
              today.hicriMonth != ramadanHicriMonth
        else { return nil }
        let upcoming: [PrayerDay] = schedule.days.filter { day in
            day.dayStart > today.dayStart && day.hicriMonth == ramadanHicriMonth
        }
        guard let firstRamadan = upcoming.min(by: { $0.dayStart < $1.dayStart }) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        return cal.dateComponents([.day], from: today.dayStart, to: firstRamadan.dayStart).day
    }
}

#if DEBUG
extension PrayerSchedule {
    /// `-uiTestRamadan` doğrulaması için: tüm günleri Ramazan 12. günü gibi işaretler.
    func forcingRamadanForUITest() -> PrayerSchedule {
        let mapped = days.map { day in
            PrayerDay(dayStart: day.dayStart, times: day.times,
                      hicriDate: "12 Ramazan 1448", hicriMonth: 9, hicriDay: 12,
                      qiblaTime: day.qiblaTime)
        }
        return PrayerSchedule(placeName: placeName, latitude: latitude, longitude: longitude,
                              timeZoneIdentifier: timeZoneIdentifier, source: source,
                              fetchedAt: fetchedAt, days: mapped)
    }
}
#endif
