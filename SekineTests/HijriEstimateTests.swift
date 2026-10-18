import XCTest
@testable import Sekine

final class HijriEstimateTests: XCTestCase {
    private let istanbul = TimeZone(identifier: "Europe/Istanbul")!

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = istanbul
        return cal.date(from: DateComponents(timeZone: istanbul, year: y, month: m, day: d, hour: hour))!
    }

    func testRamadan2027FallsInFebruary() {
        let est = HijriEstimate.estimate(for: date(2027, 2, 15), timeZone: istanbul)
        XCTAssertEqual(est?.month, 9)
        XCTAssertEqual(est?.year, 1448)
    }

    func testDayBeforeRamadanIsShaban() {
        let est = HijriEstimate.estimate(for: date(2027, 2, 1), timeZone: istanbul)
        XCTAssertEqual(est?.month, 8)
    }

    func testBoundaryFlag() {
        XCTAssertTrue(HijriEstimate(month: 9, day: 1, year: 1448).isBoundary)
        XCTAssertTrue(HijriEstimate(month: 9, day: 30, year: 1448).isBoundary)
        XCTAssertFalse(HijriEstimate(month: 9, day: 12, year: 1448).isBoundary)
    }
}
