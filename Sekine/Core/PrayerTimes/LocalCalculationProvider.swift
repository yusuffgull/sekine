import Foundation
import Adhan

/// Ağ yokken / ilk fetch öncesi yaklaşık hesap (adhan-swift, Turkey metodu).
/// Diyanet resmi tablosundan birkaç dakika sapabilir → yalnızca fallback.
struct LocalCalculationProvider: PrayerTimeProvider {
    let sourceIdentifier = "local-adhan"

    func fetchSchedule(
        latitude: Double,
        longitude: Double,
        placeName: String,
        year: Int
    ) async throws -> PrayerSchedule {
        let tz = TimeZone(identifier: "Europe/Istanbul") ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        var params = CalculationMethod.turkey.params

        guard let start = cal.date(from: DateComponents(timeZone: tz, year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(timeZone: tz, year: year, month: 12, day: 31))
        else { throw PrayerProviderError.emptyResult }

        var days: [PrayerDay] = []
        var cursor = start
        while cursor <= end {
            let dc = cal.dateComponents([.year, .month, .day], from: cursor)
            if let pt = PrayerTimes(coordinates: coordinates, date: dc, calculationParameters: params) {
                let dayStart = cal.startOfDay(for: cursor)
                let times: [PrayerTime] = [
                    .init(prayer: .fajr, date: pt.fajr),
                    .init(prayer: .sunrise, date: pt.sunrise),
                    .init(prayer: .dhuhr, date: pt.dhuhr),
                    .init(prayer: .asr, date: pt.asr),
                    .init(prayer: .maghrib, date: pt.maghrib),
                    .init(prayer: .isha, date: pt.isha)
                ]
                days.append(PrayerDay(dayStart: dayStart, times: times.sorted { $0.date < $1.date }))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        guard !days.isEmpty else { throw PrayerProviderError.emptyResult }

        return PrayerSchedule(
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: tz.identifier,
            source: sourceIdentifier,
            fetchedAt: Date(),
            days: days
        )
    }
}
