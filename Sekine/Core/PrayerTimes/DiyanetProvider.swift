import Foundation

/// Diyanet resmi vakitleri (namazvakti.diyanet.gov.tr verisini yansıtan ezanvakti
/// servisi üzerinden). İlçe ID'si gerektirir; birebir Diyanet uyumu sağlar.
/// ~1 aylık kayan pencere döner; kapsam azaldıkça PrayerTimeStore yeniden çeker.
struct DiyanetProvider: PrayerTimeProvider {
    let sourceIdentifier = "diyanet"

    static let baseURL = "https://ezanvakti.emushaf.net"
    static let countryID = "2" // Türkiye

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func canHandle(_ location: SavedLocation) -> Bool {
        location.diyanetDistrictID != nil
    }

    func fetchSchedule(for location: SavedLocation) async throws -> PrayerSchedule {
        guard let districtID = location.diyanetDistrictID else {
            throw PrayerProviderError.emptyResult
        }
        guard let url = URL(string: "\(Self.baseURL)/vakitler/\(districtID)") else {
            throw PrayerProviderError.decoding
        }

        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw PrayerProviderError.network(underlying: error)
        }

        let raw: [DiyanetVakit]
        do {
            raw = try JSONDecoder().decode([DiyanetVakit].self, from: data)
        } catch {
            throw PrayerProviderError.decoding
        }

        let tz = TimeZone(identifier: "Europe/Istanbul")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let days = raw.compactMap { $0.toPrayerDay(calendar: cal, timeZone: tz) }
            .sorted { $0.dayStart < $1.dayStart }
        guard !days.isEmpty else { throw PrayerProviderError.emptyResult }

        return PrayerSchedule(
            placeName: location.name,
            latitude: location.latitude,
            longitude: location.longitude,
            timeZoneIdentifier: tz.identifier,
            source: sourceIdentifier,
            fetchedAt: Date(),
            days: days)
    }
}

// MARK: - ezanvakti JSON

struct DiyanetVakit: Decodable {
    let MiladiTarihKisa: String  // "dd.MM.yyyy"
    let Imsak: String
    let Gunes: String
    let Ogle: String
    let Ikindi: String
    let Aksam: String
    let Yatsi: String
    let HicriTarihUzun: String?  // "26 Safer 1448"
    let KibleSaati: String?      // "HH:mm" — güneş-kıble hizalanma anı

    func toPrayerDay(calendar cal: Calendar, timeZone tz: TimeZone) -> PrayerDay? {
        let dateParts = MiladiTarihKisa.split(separator: ".").compactMap { Int($0) }
        guard dateParts.count == 3 else { return nil }
        let (dd, mm, yyyy) = (dateParts[0], dateParts[1], dateParts[2])

        func makeDate(_ hm: String) -> Date? {
            let p = hm.split(separator: ":").compactMap { Int($0) }
            guard p.count == 2 else { return nil }
            return cal.date(from: DateComponents(
                timeZone: tz, year: yyyy, month: mm, day: dd, hour: p[0], minute: p[1]))
        }

        let mapping: [(Prayer, String)] = [
            (.fajr, Imsak), (.sunrise, Gunes), (.dhuhr, Ogle),
            (.asr, Ikindi), (.maghrib, Aksam), (.isha, Yatsi)
        ]
        var times: [PrayerTime] = []
        for (prayer, raw) in mapping {
            guard let d = makeDate(raw) else { continue }
            times.append(PrayerTime(prayer: prayer, date: d))
        }
        guard times.count == 6,
              let dayStart = cal.date(from: DateComponents(
                  timeZone: tz, year: yyyy, month: mm, day: dd, hour: 0, minute: 0))
        else { return nil }
        return PrayerDay(
            dayStart: dayStart,
            times: times.sorted { $0.date < $1.date },
            hicriDate: HicriTarihUzun,
            qiblaTime: KibleSaati.flatMap(makeDate))
    }
}
