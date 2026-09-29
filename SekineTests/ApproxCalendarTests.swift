import XCTest
@testable import Sekine

final class ApproxCalendarTests: XCTestCase {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func day(_ y: Int, _ m: Int, _ d: Int, tz: TimeZone) -> PrayerDay {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let start = cal.date(from: DateComponents(timeZone: tz, year: y, month: m, day: d))!
        return PrayerDay(dayStart: start, times: [PrayerTime(prayer: .fajr, date: start.addingTimeInterval(4 * 3600))])
    }

    func testExactDaysWinAndApproxOnlyAfterWindow() {
        let exact = [day(2026, 9, 29, tz: berlin), day(2026, 9, 30, tz: berlin)]
        let approx = [day(2026, 9, 29, tz: berlin), day(2026, 9, 30, tz: berlin),
                      day(2026, 10, 1, tz: berlin), day(2026, 10, 2, tz: berlin)]
        let merged = ApproxCalendar.merge(exact: exact, exactTimeZone: berlin,
                                          approx: approx, approxTimeZone: berlin)
        XCTAssertEqual(merged.map(\.isApproximate), [false, false, true, true])
        XCTAssertEqual(merged.count, 4, "aynı gün iki kez görünmemeli")
    }

    func testWithoutExactApproxStartsToday() {
        let now = day(2026, 9, 30, tz: berlin).dayStart.addingTimeInterval(3600)
        let approx = [day(2026, 9, 29, tz: berlin), day(2026, 9, 30, tz: berlin), day(2026, 10, 1, tz: berlin)]
        let merged = ApproxCalendar.merge(exact: [], exactTimeZone: berlin,
                                          approx: approx, approxTimeZone: berlin, now: now)
        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.allSatisfy(\.isApproximate))
    }

    func testSafetyMarginDirections() {
        // İftar geç, imsak erken: oruç için güvenli yön. Tüm pay belgelenmiş ölçümden gelir.
        XCTAssertGreaterThanOrEqual(ApproxSafetyMargin.minutes[.maghrib] ?? 0, 3)
        XCTAssertLessThan(ApproxSafetyMargin.minutes[.fajr] ?? 0, 0)
        XCTAssertGreaterThan(ApproxSafetyMargin.minutes[.dhuhr] ?? 0, 0)
    }

    func testNeedsRefresh() {
        let now = Date()
        func sched(fetched: Date, lastDayOffsetDays: Double, lat: Double = 52.5) -> ApproxSchedule {
            ApproxSchedule(placeName: "Berlin", latitude: lat, longitude: 13.4,
                           timeZoneIdentifier: "Europe/Berlin", fetchedAt: fetched,
                           days: [PrayerDay(dayStart: now.addingTimeInterval(lastDayOffsetDays * 86400), times: [])])
        }
        XCTAssertTrue(ApproxCalendar.needsRefresh(nil, latitude: 52.5, longitude: 13.4, now: now))
        XCTAssertFalse(ApproxCalendar.needsRefresh(sched(fetched: now, lastDayOffsetDays: 200),
                                                   latitude: 52.5, longitude: 13.4, now: now))
        XCTAssertTrue(ApproxCalendar.needsRefresh(sched(fetched: now.addingTimeInterval(-15 * 86400), lastDayOffsetDays: 200),
                                                  latitude: 52.5, longitude: 13.4, now: now), "14 günden eski")
        XCTAssertTrue(ApproxCalendar.needsRefresh(sched(fetched: now, lastDayOffsetDays: 30),
                                                  latitude: 52.5, longitude: 13.4, now: now), "kapsam 60 günün altında")
        XCTAssertTrue(ApproxCalendar.needsRefresh(sched(fetched: now, lastDayOffsetDays: 200),
                                                  latitude: 41.0, longitude: 29.0, now: now), "konum değişti")
    }

    /// Aladhan çıktısına güvenlik payı GERÇEKTEN uygulanıyor mu (sağlayıcı seviyesinde).
    func testProviderAppliesSafetyMargin() async throws {
        let json = """
        {"data":{"1":[{"timings":{"Fajr":"05:00 (CET)","Sunrise":"07:00 (CET)","Dhuhr":"12:00 (CET)","Asr":"14:30 (CET)","Maghrib":"17:00 (CET)","Isha":"18:30 (CET)"},
        "date":{"gregorian":{"date":"15-01-2027"}},"meta":{"timezone":"Europe/Berlin"}}]}}
        """
        StubURLProtocol.responseData = Data(json.utf8)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        let provider = AladhanProvider(session: URLSession(configuration: cfg))
        let plain = try await provider.fetchYear(latitude: 52.5, longitude: 13.4, year: 2027)
        let safe = try await provider.fetchYear(latitude: 52.5, longitude: 13.4, year: 2027,
                                                safetyMinutes: ApproxSafetyMargin.minutes)
        for (prayer, minutes) in ApproxSafetyMargin.minutes {
            let a = plain.days[0].time(for: prayer)!, b = safe.days[0].time(for: prayer)!
            XCTAssertEqual(b.timeIntervalSince(a), TimeInterval(minutes * 60), "\(prayer)")
        }
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
