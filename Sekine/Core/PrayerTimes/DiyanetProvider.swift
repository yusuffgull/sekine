import Foundation

/// Diyanet resmi vakitleri (namazvakti.diyanet.gov.tr verisini yansıtan ezanvakti
/// servisi üzerinden). İlçe ID'si gerektirir; birebir Diyanet uyumu sağlar.
/// ~1 aylık kayan pencere döner; kapsam azaldıkça PrayerTimeStore yeniden çeker.
struct DiyanetProvider: PrayerTimeProvider {
    let sourceIdentifier = "diyanet"

    static let baseURL = "https://ezanvakti.emushaf.net"

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

        // Türkiye ofseti yalnızca API kendi ofsetini vermediği (beklenmeyen/eksik veri)
        // durumlarda YEDEK olarak kullanılır — her günün GERÇEK ofseti kendi
        // `MiladiTarihUzunIso8601` alanından ayrıştırılır (bkz. `DiyanetVakit.toPrayerDay`).
        let fallbackTZ = TimeZone(identifier: "Europe/Istanbul")!
        let cal = Calendar(identifier: .gregorian)

        let days = raw.compactMap { $0.toPrayerDay(calendar: cal, defaultTimeZone: fallbackTZ) }
            .sorted { $0.dayStart < $1.dayStart }
        guard !days.isEmpty else { throw PrayerProviderError.emptyResult }

        // Şema-seviyesi tek bir `timeZoneIdentifier` taşıyoruz (bkz. `PrayerSchedule`);
        // her günün MUTLAK `Date`'i zaten kendi doğru ofsetiyle hesaplandı, bu yalnızca
        // "hangi gün kovasına düşüyor" (`day(containing:)`) ve ekranda gösterim için
        // kullanılıyor. İlk günün ofseti temsilci alınır — DST geçişi tam kayan
        // pencerenin ortasına denk gelirse (yılda en fazla 2 gün, yalnızca DST uygulayan
        // ülkelerde) gün sınırı ~1 saatlik dar bir pencerede yanlış kovaya düşebilir;
        // bilinçli kabul edilen dar sınır (bkz. `docs/decisions.md`, 2026-09-24).
        let firstDayOffset = DiyanetVakit.parseUTCOffsetSeconds(
            fromISO8601: raw.first?.MiladiTarihUzunIso8601)
        let scheduleTZIdentifier = firstDayOffset.flatMap { TimeZone(secondsFromGMT: $0)?.identifier }
            ?? fallbackTZ.identifier

        return PrayerSchedule(
            placeName: location.name,
            latitude: location.latitude,
            longitude: location.longitude,
            timeZoneIdentifier: scheduleTZIdentifier,
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
    let HicriTarihKisa: String?  // "26.2.1448" (gün.ay.yıl)
    let KibleSaati: String?      // "HH:mm" — güneş-kıble hizalanma anı
    /// ör. "2026-09-19T00:00:00.0000000+02:00" — SADECE bu alanın offset kısmı
    /// (`+02:00`) güvenilir: konumun GERÇEK UTC ofseti, hedef ülkenin kendi yaz/kış
    /// saati kuralına göre günlük hesaplanmış. `GreenwichOrtalamaZamani` alanı BUNUN
    /// aksine yurt dışı ilçelerde gözlemsel olarak hep Türkiye'nin kendi ofsetini
    /// döndürüyor (yanlış) — bilinçli olarak KULLANILMIYOR, decode bile edilmiyor.
    let MiladiTarihUzunIso8601: String?

    /// `MiladiTarihUzunIso8601`'in sondaki `±HH:MM` kısmını UTC ofset saniyesine çevirir.
    /// Ayrıştırılamazsa (alan yok/`Z`/beklenmedik biçim) `nil` — çağıran taraf bir
    /// varsayılana düşer, ASLA yanlış bir ofset üretmez.
    static func parseUTCOffsetSeconds(fromISO8601 iso: String?) -> Int? {
        guard let iso, iso.count >= 6 else { return nil }
        let suffix = iso.suffix(6)
        guard let sign = suffix.first, sign == "+" || sign == "-" else { return nil }
        let hh = suffix.dropFirst().prefix(2)
        let mm = suffix.suffix(2)
        guard let h = Int(hh), let m = Int(mm), (0...23).contains(h), (0...59).contains(m)
        else { return nil }
        let total = h * 3600 + m * 60
        return sign == "-" ? -total : total
    }

    /// `defaultTimeZone`: API'nin kendi ofset bilgisi ayrıştırılamazsa kullanılacak
    /// yedek (çağıran taraf genelde `Europe/Istanbul` geçer — geriye dönük uyumlu
    /// davranış). Ayrıştırılabiliyorsa GERÇEK konum ofseti KULLANILIR — yurt dışı bir
    /// ilçe için sessizce Türkiye saatiyle hesaplama yapılmasını önler (bkz.
    /// `docs/decisions.md`, konum ofseti sessizce yanlış olamaz).
    func toPrayerDay(calendar: Calendar, defaultTimeZone: TimeZone) -> PrayerDay? {
        let tz = Self.parseUTCOffsetSeconds(fromISO8601: MiladiTarihUzunIso8601)
            .flatMap { TimeZone(secondsFromGMT: $0) } ?? defaultTimeZone
        var cal = calendar
        cal.timeZone = tz

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
        // "26.2.1448" → ay=2, gün=26
        var hMonth: Int?
        var hDay: Int?
        if let parts = HicriTarihKisa?.split(separator: ".").compactMap({ Int($0) }),
           parts.count == 3 {
            hDay = parts[0]
            hMonth = parts[1]
        }

        return PrayerDay(
            dayStart: dayStart,
            times: times.sorted { $0.date < $1.date },
            hicriDate: HicriTarihUzun,
            hicriMonth: hMonth,
            hicriDay: hDay,
            qiblaTime: KibleSaati.flatMap(makeDate))
    }
}
