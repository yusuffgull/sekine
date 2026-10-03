import XCTest
@testable import Sekine

final class ReviewPromptTests: XCTestCase {
    private var defaults: UserDefaults!
    private var cal: Calendar!

    override func setUp() {
        defaults = UserDefaults(suiteName: "ReviewPromptTests-\(UUID().uuidString)")
        cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    }

    private func open(on day: Int, times: Int = 1, _ prompt: ReviewPrompt) {
        let d = cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2026, month: 10, day: day, hour: 12))!
        for _ in 0..<times { prompt.recordOpen(now: d, calendar: cal) }
    }

    func testSameDayManyOpensIsNotRegularUse() {
        let p = ReviewPrompt(defaults: defaults)
        open(on: 1, times: 10, p)
        XCTAssertEqual(p.activeDayCount, 1)
        XCTAssertFalse(p.shouldAsk(version: "1.8", positiveMoment: true))
    }

    func testPositiveMomentNeedsThreeDaysAndFiveOpens() {
        let p = ReviewPrompt(defaults: defaults)
        open(on: 1, times: 2, p); open(on: 2, times: 2, p)
        XCTAssertFalse(p.shouldAsk(version: "1.8", positiveMoment: true), "2 gün, 4 açılış yetmez")
        open(on: 3, p)
        XCTAssertTrue(p.shouldAsk(version: "1.8", positiveMoment: true))
        XCTAssertFalse(p.shouldAsk(version: "1.8", positiveMoment: false), "açılışta 7 gün gerekir")
    }

    func testFallbackAtLaunchNeedsSevenDays() {
        let p = ReviewPrompt(defaults: defaults)
        for d in 1...6 { open(on: d, p) }
        XCTAssertFalse(p.shouldAsk(version: "1.8", positiveMoment: false))
        open(on: 7, p)
        XCTAssertTrue(p.shouldAsk(version: "1.8", positiveMoment: false))
    }

    func testAsksOncePerVersion() {
        let p = ReviewPrompt(defaults: defaults)
        for d in 1...7 { open(on: d, p) }
        p.markAsked(version: "1.8")
        XCTAssertFalse(p.shouldAsk(version: "1.8", positiveMoment: true))
        XCTAssertTrue(p.shouldAsk(version: "1.9", positiveMoment: true), "yeni sürümde tekrar sorulabilir")
    }
}
