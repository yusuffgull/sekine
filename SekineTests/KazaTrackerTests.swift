import XCTest
@testable import Sekine

@MainActor
final class KazaTrackerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "KazaTrackerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try super.tearDownWithError()
    }

    private func makeTracker() -> KazaTracker {
        KazaTracker(defaults: defaults, calendar: calendar)
    }

    // MARK: - Borç / tamamlama

    func testAddDebtIncreasesRemaining() {
        let tracker = makeTracker()
        tracker.addDebt(.dhuhr, count: 5)
        XCTAssertEqual(tracker.remaining(for: .dhuhr), 5)
        XCTAssertEqual(tracker.totalRemaining, 5)
    }

    func testLogCompletionDecrementsAndNeverGoesNegative() {
        let tracker = makeTracker()
        tracker.addDebt(.fajr, count: 1)
        tracker.logCompletion(.fajr)
        XCTAssertEqual(tracker.remaining(for: .fajr), 0)
        // Borç zaten 0 iken de kılınabilir (nafile kaza) — 0'ın altına inmez.
        tracker.logCompletion(.fajr)
        XCTAssertEqual(tracker.remaining(for: .fajr), 0)
    }

    func testSetRemainingClampsAtZero() {
        let tracker = makeTracker()
        tracker.setRemaining(.isha, to: -10)
        XCTAssertEqual(tracker.remaining(for: .isha), 0)
        tracker.setRemaining(.isha, to: 42)
        XCTAssertEqual(tracker.remaining(for: .isha), 42)
    }

    func testKazaPrayersExcludesSunrise() {
        XCTAssertFalse(KazaTracker.kazaPrayers.contains(.sunrise))
        XCTAssertEqual(KazaTracker.kazaPrayers.count, 5)
    }

    // MARK: - Kalıcılık

    func testRemainingAndLogPersistAcrossInstances() {
        let first = makeTracker()
        first.addDebt(.asr, count: 3)
        first.logCompletion(.asr)

        let second = makeTracker()
        XCTAssertEqual(second.remaining(for: .asr), 2)
        XCTAssertEqual(second.completions(inLast: 1), 1)
    }

    // MARK: - Seri (streak) — saf fonksiyon, gerçek Date'e bağımlı değil

    func testStreakIsZeroForEmptyLog() {
        XCTAssertEqual(KazaTracker.computeStreak(from: [], calendar: calendar, asOf: Date()), 0)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let today = calendar.startOfDay(for: Date())
        let log = [0, 1, 2].compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        XCTAssertEqual(KazaTracker.computeStreak(from: log, calendar: calendar, asOf: today), 3)
    }

    /// Bugün henüz kayıt yoksa ama dün vardıysa seri sıfırlanmaz (gün bitmeden
    /// cezalandırılmamalı) — dünden geriye doğru sayılır.
    func testStreakGrantsGracePeriodWhenTodayNotYetLogged() {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        XCTAssertEqual(
            KazaTracker.computeStreak(from: [yesterday, twoDaysAgo], calendar: calendar, asOf: today), 2)
    }

    /// İki gün önceki tek bir kayıt (dün ve bugün BOŞ) seriyi sıfırlamalı.
    func testStreakResetsAfterGap() {
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        XCTAssertEqual(KazaTracker.computeStreak(from: [twoDaysAgo], calendar: calendar, asOf: today), 0)
    }

    /// Aynı gün içinde birden çok kayıt seriyi tek gün olarak saymalı (mükerrer değil).
    func testStreakDedupesSameDayMultipleCompletions() {
        let today = calendar.startOfDay(for: Date())
        let log = [today, today, today]
        XCTAssertEqual(KazaTracker.computeStreak(from: log, calendar: calendar, asOf: today), 1)
    }

    // MARK: - İstatistik

    func testCompletionsInLastNDaysFiltersOldEntries() {
        let tracker = makeTracker()
        tracker.addDebt(.maghrib, count: 2)
        tracker.logCompletion(.maghrib)
        XCTAssertEqual(tracker.completions(inLast: 7), 1)
        XCTAssertEqual(tracker.completions(inLast: 0), 0)
    }
}
