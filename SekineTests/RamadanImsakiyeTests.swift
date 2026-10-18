import XCTest
@testable import Sekine

final class RamadanImsakiyeTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Istanbul")!
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = tz; return c }

    private func entry(_ y: Int, _ m: Int, _ d: Int, hicri: (Int, Int)? = nil, approx: Bool = false) -> MonthlyEntry {
        let start = cal.date(from: DateComponents(timeZone: tz, year: y, month: m, day: d))!
        let times = [PrayerTime(prayer: .fajr, date: start.addingTimeInterval(5.5 * 3600)),
                     PrayerTime(prayer: .dhuhr, date: start.addingTimeInterval(13 * 3600)),
                     PrayerTime(prayer: .asr, date: start.addingTimeInterval(16 * 3600)),
                     PrayerTime(prayer: .maghrib, date: start.addingTimeInterval(18 * 3600)),
                     PrayerTime(prayer: .isha, date: start.addingTimeInterval(20 * 3600))]
        let day = PrayerDay(dayStart: start, times: times, hicriDate: nil,
                            hicriMonth: hicri?.0, hicriDay: hicri?.1)
        return MonthlyEntry(day: day, isApproximate: approx, timeZone: tz)
    }

    func testCertainRowsComeFromDiyanetHijriOnly() {
        let e = [entry(2027, 2, 7, hicri: (8, 30)), entry(2027, 2, 8, hicri: (9, 1)), entry(2027, 2, 9, hicri: (9, 2))]
        let r = RamadanImsakiye.build(from: e)
        XCTAssertEqual(r.rows.map(\.dayNumber), [1, 2])
        XCTAssertTrue(r.rows.allSatisfy { !$0.isDateEstimated })
        XCTAssertFalse(r.hasEstimates)
    }

    func testEstimatedRowsWhenNoHijriData() {
        // Umm al-Qura: 1 Ramazan 1448 = 8 Şubat 2027.
        let e = (1...12).map { entry(2027, 2, $0) }
        let r = RamadanImsakiye.build(from: e)
        XCTAssertEqual(r.rows.first?.dayNumber, 1)
        XCTAssertTrue(r.rows.allSatisfy(\.isDateEstimated))
        XCTAssertTrue(r.rows.first?.isBoundary == true)
        XCTAssertTrue(r.hasEstimates)
    }

    func testEstimatesContinueNumberingAfterCertainRows() {
        let e = [entry(2027, 2, 8, hicri: (9, 1)), entry(2027, 2, 9, hicri: (9, 2)),
                 entry(2027, 2, 10, approx: true), entry(2027, 2, 11, approx: true)]
        let r = RamadanImsakiye.build(from: e)
        XCTAssertEqual(r.rows.map(\.dayNumber), [1, 2, 3, 4])
        XCTAssertEqual(r.rows.map(\.isDateEstimated), [false, false, true, true])
        XCTAssertEqual(r.rows.map(\.isTimeApproximate), [false, false, true, true])
    }

    func testNonRamadanRangeProducesNoRows() {
        let e = (1...5).map { entry(2027, 5, $0) }
        XCTAssertTrue(RamadanImsakiye.build(from: e).rows.isEmpty)
    }

    func testNeverMoreThanThirtyRows() {
        let e = (0..<40).map { i -> MonthlyEntry in
            let d = cal.date(byAdding: .day, value: i, to: cal.date(from: DateComponents(timeZone: tz, year: 2027, month: 2, day: 8))!)!
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return entry(c.year!, c.month!, c.day!)
        }
        XCTAssertLessThanOrEqual(RamadanImsakiye.build(from: e).rows.count, 30)
    }
}

@MainActor
final class RamadanImsakiyeCardTests: XCTestCase {
    func testCardRendersAtExpectedSizeAndCanExport() throws {
        let tz = TimeZone(identifier: "Europe/Istanbul")!
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let first = cal.date(from: DateComponents(timeZone: tz, year: 2027, month: 2, day: 8))!
        let entries: [MonthlyEntry] = (0..<30).map { i in
            let start = cal.date(byAdding: .day, value: i, to: first)!
            let times = [PrayerTime(prayer: .fajr, date: start.addingTimeInterval(5.5 * 3600 - Double(i) * 60)),
                         PrayerTime(prayer: .maghrib, date: start.addingTimeInterval(18 * 3600 + Double(i) * 60))]
            let certain = i < 20
            return MonthlyEntry(day: PrayerDay(dayStart: start, times: times,
                                               hicriMonth: certain ? 9 : nil, hicriDay: certain ? i + 1 : nil),
                                isApproximate: !certain, timeZone: tz)
        }
        let im = RamadanImsakiye.build(from: entries)
        // Umm al-Qura'ya göre 9 Mart 2027 Şevval 1 → Ramazan 29 satır (30. gün yok).
        XCTAssertEqual(im.rows.count, 29)
        let image = try XCTUnwrap(RamadanImsakiyeCardRenderer.image(imsakiye: im, placeName: "İstanbul"))
        XCTAssertEqual(image.size.width, 1080)
        XCTAssertEqual(image.size.height, 1920)
        if let dir = ProcessInfo.processInfo.environment["SEKINE_EXPORT_DIR"], let png = image.pngData() {
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("imsakiye-card.png"))
        }
    }
}
