import XCTest
@testable import Sekine

@MainActor
final class ShareCardTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Berlin")!

    private func makeDay(hicriMonth: Int?, hicriDay: Int?) -> PrayerDay {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        func t(_ p: Prayer, _ h: Int, _ m: Int) -> PrayerTime {
            PrayerTime(prayer: p, date: cal.date(from: DateComponents(
                timeZone: tz, year: 2027, month: 2, day: 9, hour: h, minute: m))!)
        }
        return PrayerDay(
            dayStart: cal.date(from: DateComponents(timeZone: tz, year: 2027, month: 2, day: 9))!,
            times: [t(.fajr, 6, 10), t(.sunrise, 7, 55), t(.dhuhr, 12, 30),
                    t(.asr, 15, 10), t(.maghrib, 17, 20), t(.isha, 18, 55)],
            hicriDate: "2 Ramazan 1448", hicriMonth: hicriMonth, hicriDay: hicriDay)
    }

    func testRendersFixedSizeImage() throws {
        let image = try XCTUnwrap(ShareCardRenderer.image(
            placeName: "Berlin", day: makeDay(hicriMonth: 9, hicriDay: 2), timeZone: tz))
        XCTAssertEqual(image.size.width * image.scale, 1080, accuracy: 0.5)
        XCTAssertEqual(image.size.height * image.scale, 1350, accuracy: 0.5)
    }

    func testRamadanLabelsOnlyInRamadan() {
        XCTAssertEqual(ShareCardView.label(.maghrib, ramadan: true), "Akşam (iftar)")
        XCTAssertEqual(ShareCardView.label(.fajr, ramadan: true), "İmsak (sahur sonu)")
        XCTAssertEqual(ShareCardView.label(.maghrib, ramadan: false), "Akşam")
        XCTAssertEqual(ShareCardView.label(.dhuhr, ramadan: true), "Öğle")
    }
}
