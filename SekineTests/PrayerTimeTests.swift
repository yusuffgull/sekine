import XCTest
import CoreLocation
@testable import Sekine

final class PrayerTimeTests: XCTestCase {

    private func makeSchedule() -> PrayerSchedule {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let day0 = cal.date(from: DateComponents(
            timeZone: cal.timeZone, year: 2026, month: 8, day: 1, hour: 0))!
        func t(_ p: Prayer, _ h: Int, _ m: Int) -> PrayerTime {
            PrayerTime(prayer: p, date: cal.date(from: DateComponents(
                timeZone: cal.timeZone, year: 2026, month: 8, day: 1, hour: h, minute: m))!)
        }
        let day = PrayerDay(dayStart: day0, times: [
            t(.fajr, 4, 8), t(.sunrise, 5, 53), t(.dhuhr, 13, 15),
            t(.asr, 17, 10), t(.maghrib, 20, 27), t(.isha, 22, 4)
        ])
        return PrayerSchedule(
            placeName: "İstanbul", latitude: 41.0082, longitude: 28.9784,
            timeZoneIdentifier: "Europe/Istanbul", source: "test",
            fetchedAt: Date(), days: [day])
    }

    // MARK: - İl/ilçe ad düzeltmesi + alias (bundle'lı override)

    func testDistrictNameFixAndIstanbulAliases() {
        // emushaf'ın İstanbul için döndürdüğü (eksik/ASCII-hasarlı) örnek alt küme.
        let dtos = [
            DiyanetDistrictDTO(IlceAdi: "ARNAVUTKOY", IlceID: "9535"),
            DiyanetDistrictDTO(IlceAdi: "İSTANBUL", IlceID: "9541"),
            DiyanetDistrictDTO(IlceAdi: "ÇEKMEKÖY", IlceID: "9539"),
        ]
        let result = DiyanetDirectory.applyingOverrides(dtos, cityID: "539")
        let byName = Dictionary(grouping: result, by: \.name).mapValues { $0.first! }

        // ASCII-hasarlı ad doğru Türkçe'ye düzeldi.
        XCTAssertNotNil(byName["Arnavutköy"], "Arnavutköy adı düzelmeli")
        XCTAssertEqual(byName["Arnavutköy"]?.IlceID, "9535", "ID (vakit) değişmemeli")
        // Zaten doğru olan ad korunur.
        XCTAssertNotNil(byName["Çekmeköy"])
        // Eksik idari ilçeler alias olarak eklendi ve merkez (İstanbul) ID'sine bağlı.
        XCTAssertEqual(byName["Üsküdar"]?.IlceID, "9541", "Üsküdar merkez ID'ye bağlanmalı")
        XCTAssertEqual(byName["Ataşehir"]?.IlceID, "9541")
        XCTAssertEqual(byName["Kadıköy"]?.IlceID, "9541")
        // Liste kimlikleri benzersiz (alias'lar aynı IlceID'yi paylaşsa da).
        XCTAssertEqual(Set(result.map(\.id)).count, result.count, "id çakışması olmamalı")
    }

    func testExtraNotificationsContent() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let d = cal.date(from: DateComponents(
            timeZone: cal.timeZone, year: 2026, month: 8, day: 25))!

        // dateKey biçimi
        XCTAssertEqual(ExtraNotifications.dateKey(d, cal), "2026-08-25")

        // Sabit Hicri eşleşme: Mevlid = 12 Rebiülevvel (ay 3, gün 12)
        let mevlid = ExtraNotifications.holyDay(hijriMonth: 3, hijriDay: 12, weekday: nil)
        XCTAssertEqual(mevlid?.name, "Mevlid Kandili")
        XCTAssertEqual(mevlid?.isEve, true)

        // Regaib: Recep (7) ilk Cuması → gün ≤ 7 ve Cuma (weekday 6)
        XCTAssertEqual(
            ExtraNotifications.holyDay(hijriMonth: 7, hijriDay: 3, weekday: 6)?.name,
            "Regaib Kandili")
        // Recep 3 ama Perşembe (weekday 5) → Regaib değil
        XCTAssertNil(ExtraNotifications.holyDay(hijriMonth: 7, hijriDay: 3, weekday: 5))
        // Bayram gündüz: Kurban = 10 Zilhicce (ay 12, gün 10), eve=false
        XCTAssertEqual(ExtraNotifications.holyDay(hijriMonth: 12, hijriDay: 10, weekday: nil)?.isEve, false)

        // Özel günde temalı ayet gösterilir
        XCTAssertEqual(
            ExtraNotifications.verse(on: d, calendar: cal, holyDay: mevlid)?.source,
            "Enbiyâ 21/107")
        // Normal günde (holyDay nil) rotasyon dolu gelir
        XCTAssertNotNil(ExtraNotifications.verse(on: d, calendar: cal, holyDay: nil))
        // Ardışık günlerde rotasyon değişir (liste >1)
        if ExtraNotifications.dailyVerses.count > 1 {
            let next = cal.date(byAdding: .day, value: 1, to: d)!
            XCTAssertNotEqual(
                ExtraNotifications.verse(on: d, calendar: cal, holyDay: nil),
                ExtraNotifications.verse(on: next, calendar: cal, holyDay: nil))
        }
    }

    func testSpiritualContentLoads() {
        // Esmaül Hüsna: Allah + 99 isim = 100
        XCTAssertEqual(SpiritualContent.esmaulHusna.count, 100)
        XCTAssertEqual(SpiritualContent.esmaulHusna.first?.name, "Allah")
        XCTAssertEqual(SpiritualContent.esmaulHusna.last?.name, "Es-Sabûr")
        // Dualar dolu ve alanları eksiksiz
        XCTAssertGreaterThanOrEqual(SpiritualContent.duas.count, 10)
        XCTAssertTrue(SpiritualContent.duas.allSatisfy {
            !$0.title.isEmpty && !$0.reading.isEmpty && !$0.meaning.isEmpty && !$0.source.isEmpty
        })
    }

    func testNextTimeReturnsUpcomingPrayer() {
        let schedule = makeSchedule()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        let noonish = cal.date(from: DateComponents(
            timeZone: schedule.timeZone, year: 2026, month: 8, day: 1, hour: 12))!
        XCTAssertEqual(schedule.nextTime(after: noonish)?.prayer, .dhuhr)
    }

    func testCurrentTimeReturnsMostRecentPast() {
        let schedule = makeSchedule()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        let afternoon = cal.date(from: DateComponents(
            timeZone: schedule.timeZone, year: 2026, month: 8, day: 1, hour: 18))!
        XCTAssertEqual(schedule.currentTime(at: afternoon)?.prayer, .asr)
    }

    func testDayContainingMatchesSameDay() {
        let schedule = makeSchedule()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        let mid = cal.date(from: DateComponents(
            timeZone: schedule.timeZone, year: 2026, month: 8, day: 1, hour: 15))!
        XCTAssertNotNil(schedule.day(containing: mid))
        XCTAssertEqual(schedule.day(containing: mid)?.times.count, 6)
    }

    func testPrayerOrderAndNames() {
        XCTAssertEqual(Prayer.ordered.first, .fajr)
        XCTAssertEqual(Prayer.ordered.last, .isha)
        XCTAssertEqual(Prayer.fajr.displayName, "İmsak")
        XCTAssertFalse(Prayer.sunrise.isNotifiable)
        XCTAssertTrue(Prayer.dhuhr.isNotifiable)
    }

    func testQiblaBearingFromIstanbulIsSoutheast() {
        // İstanbul'dan Kâbe güneydoğudadır (~150–160°).
        let istanbul = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
        let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let bearing = QiblaManager.bearing(from: istanbul, to: kaaba)
        XCTAssertGreaterThan(bearing, 120)
        XCTAssertLessThan(bearing, 180)
    }

    func testCountdownFormatter() {
        let now = Date()
        XCTAssertEqual(CountdownFormatter.string(from: now, to: now.addingTimeInterval(3720)),
                       "1 sa 02 dk")
        XCTAssertEqual(CountdownFormatter.string(from: now, to: now.addingTimeInterval(65)),
                       "1 dk 05 sn")
        XCTAssertEqual(CountdownFormatter.string(from: now, to: now.addingTimeInterval(5)),
                       "5 sn")
        XCTAssertEqual(CountdownFormatter.string(from: now, to: now.addingTimeInterval(-10)),
                       "0 sn")
    }

    func testDiyanetVakitParsing() {
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "Europe/Istanbul")!
        cal.timeZone = tz
        let vakit = DiyanetVakit(
            MiladiTarihKisa: "01.08.2026",
            Imsak: "04:08", Gunes: "05:53", Ogle: "13:16",
            Ikindi: "17:10", Aksam: "20:28", Yatsi: "22:05",
            HicriTarihUzun: "18 Safer 1448", HicriTarihKisa: "18.2.1448", KibleSaati: "12:17")
        let day = vakit.toPrayerDay(calendar: cal, timeZone: tz)
        XCTAssertNotNil(day)
        XCTAssertEqual(day?.times.count, 6)
        let maghrib = day?.time(for: .maghrib)
        let comps = cal.dateComponents([.hour, .minute], from: maghrib ?? Date())
        XCTAssertEqual(comps.hour, 20)
        XCTAssertEqual(comps.minute, 28)
        // İmsak güneşten önce olmalı (sıralama)
        XCTAssertLessThan(day!.time(for: .fajr)!, day!.time(for: .sunrise)!)
        // Hicri tarih + kıble saati ayrıştırıldı mı
        XCTAssertEqual(day?.hicriDate, "18 Safer 1448")
        XCTAssertEqual(day?.hicriMonth, 2)
        XCTAssertEqual(day?.hicriDay, 18)
        let qc = cal.dateComponents([.hour, .minute], from: day?.qiblaTime ?? Date())
        XCTAssertEqual(qc.hour, 12)
        XCTAssertEqual(qc.minute, 17)
    }

    func testDiyanetProviderRequiresDistrictID() {
        let provider = DiyanetProvider()
        XCTAssertFalse(provider.canHandle(SavedLocation(name: "x", latitude: 41, longitude: 29)))
        XCTAssertTrue(provider.canHandle(SavedLocation(name: "x", latitude: 41, longitude: 29, diyanetDistrictID: "9541")))
    }

    func testCacheRoundTrip() {
        let schedule = makeSchedule()
        PrayerCache.save(schedule)
        let loaded = PrayerCache.load()
        XCTAssertEqual(loaded?.placeName, "İstanbul")
        XCTAssertEqual(loaded?.days.first?.times.count, 6)
    }
}
