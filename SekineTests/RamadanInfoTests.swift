import XCTest
@testable import Sekine

final class RamadanInfoTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func date(_ day: Int, _ h: Int, _ m: Int) -> Date {
        cal.date(from: DateComponents(
            timeZone: cal.timeZone, year: 2027, month: 2, day: day, hour: h, minute: m))!
    }

    /// Şubat 2027'de `day`. gün için, verilen hicri ay/gün ile sentetik bir gün.
    private func makeDay(_ day: Int, hicriMonth: Int?, hicriDay: Int?) -> PrayerDay {
        func t(_ p: Prayer, _ h: Int, _ m: Int) -> PrayerTime { PrayerTime(prayer: p, date: date(day, h, m)) }
        return PrayerDay(
            dayStart: date(day, 0, 0),
            times: [t(.fajr, 5, 30), t(.sunrise, 7, 0), t(.dhuhr, 13, 10),
                    t(.asr, 16, 10), t(.maghrib, 18, 25), t(.isha, 19, 50)],
            hicriMonth: hicriMonth, hicriDay: hicriDay)
    }

    private func makeSchedule(_ days: [PrayerDay]) -> PrayerSchedule {
        PrayerSchedule(
            placeName: "Test", latitude: nil, longitude: nil,
            timeZoneIdentifier: cal.timeZone.identifier, source: "test",
            fetchedAt: Date(), days: days)
    }

    // MARK: current

    func testNotRamadanReturnsNil() {
        let schedule = makeSchedule([makeDay(5, hicriMonth: 8, hicriDay: 27)])
        XCTAssertNil(RamadanInfo.current(schedule: schedule, now: date(5, 12, 0)))
    }

    func testMissingHicriDataReturnsNilNeverGuesses() {
        // Aladhan/yerel fallback'te hicri alanlar nil — Ramazan modu SESSİZCE kapalı kalmalı.
        let schedule = makeSchedule([makeDay(9, hicriMonth: nil, hicriDay: nil)])
        XCTAssertNil(RamadanInfo.current(schedule: schedule, now: date(9, 12, 0)))
    }

    func testBeforeFajrTargetsFajrAsSahurEnd() throws {
        let schedule = makeSchedule([makeDay(9, hicriMonth: 9, hicriDay: 2)])
        let info = try XCTUnwrap(RamadanInfo.current(schedule: schedule, now: date(9, 4, 0)))
        XCTAssertEqual(info.phase, .untilSahurEnd)
        XCTAssertEqual(info.target, date(9, 5, 30))
        XCTAssertEqual(info.dayNumber, 2)
    }

    func testDuringFastTargetsMaghribAsIftar() throws {
        let schedule = makeSchedule([makeDay(9, hicriMonth: 9, hicriDay: 2)])
        let info = try XCTUnwrap(RamadanInfo.current(schedule: schedule, now: date(9, 12, 0)))
        XCTAssertEqual(info.phase, .untilIftar)
        XCTAssertEqual(info.target, date(9, 18, 25))
    }

    func testAfterIftarTargetsTomorrowsFajr() throws {
        let schedule = makeSchedule([
            makeDay(9, hicriMonth: 9, hicriDay: 2),
            makeDay(10, hicriMonth: 9, hicriDay: 3)])
        let info = try XCTUnwrap(RamadanInfo.current(schedule: schedule, now: date(9, 21, 0)))
        XCTAssertEqual(info.phase, .untilSahurEnd)
        XCTAssertEqual(info.target, date(10, 5, 30))
        XCTAssertEqual(info.dayNumber, 2, "Gün numarası bugünün Diyanet hicri gününden gelir")
    }

    func testAfterIftarWithoutTomorrowReturnsNilInsteadOfWrongTarget() {
        let schedule = makeSchedule([makeDay(9, hicriMonth: 9, hicriDay: 30)])
        XCTAssertNil(RamadanInfo.current(schedule: schedule, now: date(9, 21, 0)))
    }

    // MARK: daysUntilStart

    func testDaysUntilStartCountsToFirstRamadanDay() {
        let schedule = makeSchedule([
            makeDay(5, hicriMonth: 8, hicriDay: 27),
            makeDay(6, hicriMonth: 8, hicriDay: 28),
            makeDay(7, hicriMonth: 8, hicriDay: 29),
            makeDay(8, hicriMonth: 9, hicriDay: 1)])
        XCTAssertEqual(RamadanInfo.daysUntilStart(schedule: schedule, now: date(5, 12, 0)), 3)
    }

    func testDaysUntilStartNilWhenAlreadyRamadan() {
        let schedule = makeSchedule([
            makeDay(9, hicriMonth: 9, hicriDay: 2),
            makeDay(10, hicriMonth: 9, hicriDay: 3)])
        XCTAssertNil(RamadanInfo.daysUntilStart(schedule: schedule, now: date(9, 12, 0)))
    }

    func testDaysUntilStartNilWhenNoRamadanInWindow() {
        let schedule = makeSchedule([
            makeDay(5, hicriMonth: 8, hicriDay: 1),
            makeDay(6, hicriMonth: 8, hicriDay: 2)])
        XCTAssertNil(RamadanInfo.daysUntilStart(schedule: schedule, now: date(5, 12, 0)))
    }
}
