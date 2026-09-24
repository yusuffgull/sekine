import XCTest
@testable import Sekine

@MainActor
final class FastingTrackerTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "FastingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func day(_ d: Int) -> Date {
        cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2027, month: 2, day: d, hour: 15))!
    }

    func testToggleMarksAndUnmarks() {
        let t = FastingTracker(defaults: defaults)
        XCTAssertFalse(t.isFasted(day(9), calendar: cal))
        t.toggle(day(9), calendar: cal)
        XCTAssertTrue(t.isFasted(day(9), calendar: cal))
        t.toggle(day(9), calendar: cal)
        XCTAssertFalse(t.isFasted(day(9), calendar: cal))
    }

    func testPersistsAcrossInstances() {
        FastingTracker(defaults: defaults).toggle(day(9), calendar: cal)
        XCTAssertTrue(FastingTracker(defaults: defaults).isFasted(day(9), calendar: cal))
    }

    func testKeyUsesGivenCalendarTimeZone() {
        // 22:30 UTC = ertesi gün 01:30 İstanbul → anahtar İstanbul gününe göre.
        let utc = Date(timeIntervalSince1970: 1_265_754_600) // 2010-02-09 22:30 UTC
        XCTAssertEqual(FastingTracker.key(for: utc, calendar: cal), "2010-02-10")
    }

    func testFastedCountOnlyCountsCurrentRamadanDays() {
        // Bugün 3. gün (Şubat 11): 9,10,11 Ramazan; 8. Şaban (oruç değil) sayılmamalı.
        let fasted: Set<String> = ["2027-02-08", "2027-02-09", "2027-02-11"]
        let n = FastingTracker.fastedCount(in: fasted, today: day(11), dayNumber: 3, calendar: cal)
        XCTAssertEqual(n, 2)
    }

    func testFastedCountZeroForInvalidDayNumber() {
        XCTAssertEqual(FastingTracker.fastedCount(in: ["2027-02-09"], today: day(9), dayNumber: 0, calendar: cal), 0)
    }
}
