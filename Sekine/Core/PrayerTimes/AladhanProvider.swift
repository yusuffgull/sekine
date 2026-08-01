import Foundation

/// Aladhan API (method=13, Diyanet İşleri Başkanlığı) üzerinden yıllık vakitleri çeker.
/// Tek harici çağrı budur; konum dışında kişisel veri gönderilmez, tracking yoktur.
struct AladhanProvider: PrayerTimeProvider {
    let sourceIdentifier = "aladhan-13"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSchedule(
        latitude: Double,
        longitude: Double,
        placeName: String,
        year: Int
    ) async throws -> PrayerSchedule {
        var comps = URLComponents(string: "https://api.aladhan.com/v1/calendar")!
        comps.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "method", value: "13"),
            .init(name: "annual", value: "true"),
            .init(name: "year", value: String(year))
        ]
        guard let url = comps.url else { throw PrayerProviderError.decoding }

        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw PrayerProviderError.network(underlying: error)
        }

        let response: AladhanResponse
        do {
            response = try JSONDecoder().decode(AladhanResponse.self, from: data)
        } catch {
            throw PrayerProviderError.decoding
        }

        let tzIdentifier = response.data.values.first?.first?.meta.timezone ?? "Europe/Istanbul"
        let tz = TimeZone(identifier: tzIdentifier) ?? TimeZone(identifier: "Europe/Istanbul")!

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        var days: [PrayerDay] = []
        // data: ["1": [...], ..., "12": [...]]
        for month in 1...12 {
            guard let monthDays = response.data[String(month)] else { continue }
            for raw in monthDays {
                guard let day = raw.toPrayerDay(calendar: cal, timeZone: tz) else { continue }
                days.append(day)
            }
        }
        days.sort { $0.dayStart < $1.dayStart }
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

// MARK: - Aladhan JSON

private struct AladhanResponse: Decodable {
    let data: [String: [AladhanDay]]
}

private struct AladhanDay: Decodable {
    let timings: [String: String]
    let date: AladhanDate
    let meta: AladhanMeta

    func toPrayerDay(calendar cal: Calendar, timeZone tz: TimeZone) -> PrayerDay? {
        // date.gregorian.date = "dd-MM-yyyy"
        let parts = date.gregorian.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let (dd, mm, yyyy) = (parts[0], parts[1], parts[2])

        var times: [PrayerTime] = []
        let mapping: [(Prayer, String)] = [
            (.fajr, "Fajr"), (.sunrise, "Sunrise"), (.dhuhr, "Dhuhr"),
            (.asr, "Asr"), (.maghrib, "Maghrib"), (.isha, "Isha")
        ]
        for (prayer, key) in mapping {
            guard let raw = timings[key],
                  let (h, m) = Self.parseHM(raw),
                  let d = cal.date(from: DateComponents(
                      timeZone: tz, year: yyyy, month: mm, day: dd, hour: h, minute: m))
            else { continue }
            times.append(PrayerTime(prayer: prayer, date: d))
        }
        guard let dayStart = cal.date(from: DateComponents(
            timeZone: tz, year: yyyy, month: mm, day: dd, hour: 0, minute: 0))
        else { return nil }
        guard times.count >= 5 else { return nil }
        return PrayerDay(dayStart: dayStart, times: times.sorted { $0.date < $1.date })
    }

    /// "04:08 (EEST)" veya "04:08" → (4, 8)
    static func parseHM(_ raw: String) -> (Int, Int)? {
        let clock = raw.split(separator: " ").first.map(String.init) ?? raw
        let hm = clock.split(separator: ":").compactMap { Int($0) }
        guard hm.count == 2 else { return nil }
        return (hm[0], hm[1])
    }
}

private struct AladhanDate: Decodable {
    let gregorian: AladhanGregorian
}
private struct AladhanGregorian: Decodable {
    let date: String
}
private struct AladhanMeta: Decodable {
    let timezone: String
}
