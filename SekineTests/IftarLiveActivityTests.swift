import XCTest
import SwiftUI
@testable import Sekine

@MainActor
final class IftarLiveActivityTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Istanbul")!; return c
    }()
    private func date(_ h: Int, _ m: Int) -> Date {
        cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2027, month: 2, day: 9, hour: h, minute: m))!
    }
    private func schedule(hicriMonth: Int?) -> PrayerSchedule {
        func t(_ p: Prayer, _ h: Int, _ m: Int) -> PrayerTime { PrayerTime(prayer: p, date: date(h, m)) }
        let day = PrayerDay(dayStart: date(0, 0),
            times: [t(.fajr, 5, 30), t(.sunrise, 7, 0), t(.dhuhr, 13, 10), t(.asr, 16, 10), t(.maghrib, 18, 25), t(.isha, 19, 50)],
            hicriMonth: hicriMonth, hicriDay: hicriMonth == nil ? nil : 2)
        return PrayerSchedule(placeName: "T", latitude: nil, longitude: nil,
            timeZoneIdentifier: cal.timeZone.identifier, source: "t", fetchedAt: Date(), days: [day])
    }

    func testStartsDuringFastWhenNoActivity() {
        let a = IftarLiveActivityManager.action(schedule: schedule(hicriMonth: 9), now: date(12, 0), hasActive: false)
        XCTAssertEqual(a, .start(dayNumber: 2, iftar: date(18, 25)))
    }
    func testDoesNothingWhenAlreadyActive() {
        XCTAssertEqual(IftarLiveActivityManager.action(schedule: schedule(hicriMonth: 9), now: date(12, 0), hasActive: true), .none)
    }
    func testEndsAfterIftar() {
        // İftar sonrası faz sahur → aktif varsa bitir.
        XCTAssertEqual(IftarLiveActivityManager.action(schedule: schedule(hicriMonth: 9), now: date(20, 0), hasActive: true), .endAll)
    }
    func testNeverStartsOutsideRamadanOrWithoutHicriData() {
        XCTAssertEqual(IftarLiveActivityManager.action(schedule: schedule(hicriMonth: 8), now: date(12, 0), hasActive: false), .none)
        XCTAssertEqual(IftarLiveActivityManager.action(schedule: schedule(hicriMonth: nil), now: date(12, 0), hasActive: false), .none)
        XCTAssertEqual(IftarLiveActivityManager.action(schedule: nil, now: date(12, 0), hasActive: true), .endAll)
    }
    func testLockScreenViewRenders() throws {
        let view = IftarLockScreenView(dayNumber: 12, placeName: "İstanbul",
                                       iftar: Date().addingTimeInterval(3 * 3600 + 25 * 60))
            .frame(width: 370, height: 84)
            .background(Color.white)
        let r = ImageRenderer(content: view); r.scale = 3
        let img = try XCTUnwrap(r.uiImage)
        try? img.pngData()?.write(to: URL(fileURLWithPath: "/tmp/iftar-lockscreen.png"))
        XCTAssertGreaterThan(img.size.width, 300)
    }
}
