import Foundation

/// Diyanet penceresinin (~32 gün) ötesindeki günler için ÇEVRİMİÇİ hesaplanan "yaklaşık" takvim.
///
/// Bilinçli olarak `PrayerTimeStore.schedule`'dan AYRIDIR: bildirimler, widget, Watch ve
/// Ramazan sayacı yalnızca Diyanet-birebir veriyi okur; yaklaşık veri yalnızca aylık imsakiye
/// ekranında, "≈" etiketiyle gösterilir. Gerekçe ve ölçüm: `docs/decisions.md` (2026-09-29).
enum ApproxSafetyMargin {
    /// Aladhan method=13 ile Diyanet'in 14 şehirde (9 ülke, Eyl-Eki 2026) karşılaştırması:
    /// İmsak +0..+1, Güneş +0..+1, Öğle −1..0, İkindi −1..+1, **Akşam −1..−3** (iftar için
    /// güvensiz yön), Yatsı Avrupa/K.Amerika'da +3..+7 ama İstanbul/Bakü'de −1..−2.
    /// Payların hepsi oruç/namaz için GÜVENLİ yöne ekleniyor (imsak erken, iftar geç).
    static let minutes: [Prayer: Int] = [
        .fajr: -2, .sunrise: -1, .dhuhr: 1, .asr: 1, .maghrib: 3, .isha: 2
    ]
}

struct ApproxSchedule: Codable, Sendable {
    let placeName: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
    let fetchedAt: Date
    let days: [PrayerDay]

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
}

/// Aylık ekranda bir satır: günün vakitleri + bunun kesin mi yaklaşık mı olduğu.
struct MonthlyEntry: Identifiable, Sendable {
    let day: PrayerDay
    let isApproximate: Bool
    /// Günün ait olduğu konumun saat dilimi (gün/saat gösterimi bununla yapılır).
    let timeZone: TimeZone
    var id: Date { day.dayStart }
}

enum ApproxCalendar {
    /// Kesin (Diyanet) günler her zaman kazanır; yaklaşık günler yalnızca kesin pencerenin
    /// SONRASINDAki günler için eklenir. Kesin veri yoksa yaklaşık günler bugünden başlar.
    static func merge(exact: [PrayerDay], exactTimeZone: TimeZone,
                      approx: [PrayerDay], approxTimeZone: TimeZone,
                      now: Date = Date()) -> [MonthlyEntry] {
        var entries = exact.map { MonthlyEntry(day: $0, isApproximate: false, timeZone: exactTimeZone) }
        let cutoff = exact.map(\.dayStart).max()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = approxTimeZone
        let todayStart = cal.startOfDay(for: now)
        for day in approx {
            if let cutoff, day.dayStart <= cutoff { continue }
            if cutoff == nil, day.dayStart < todayStart { continue }
            entries.append(MonthlyEntry(day: day, isApproximate: true, timeZone: approxTimeZone))
        }
        return entries.sorted { $0.day.dayStart < $1.day.dayStart }
    }

    /// Yeniden çekmek gerekiyor mu? (yok, konum değişti, 14 günden eski, kapsam 60 günün altında)
    static func needsRefresh(_ cached: ApproxSchedule?, latitude: Double, longitude: Double,
                             now: Date = Date()) -> Bool {
        guard let cached else { return true }
        if abs(cached.latitude - latitude) >= 0.01 || abs(cached.longitude - longitude) >= 0.01 { return true }
        if now.timeIntervalSince(cached.fetchedAt) > 14 * 24 * 3600 { return true }
        guard let last = cached.days.map(\.dayStart).max() else { return true }
        return last.timeIntervalSince(now) < 60 * 24 * 3600
    }
}

/// Yaklaşık takvimin cihazdaki kopyası (widget/watch okumaz; yalnızca app).
enum ApproxCache {
    private static let fileName = "approx-calendar.json"

    private static var url: URL? {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent(fileName)
    }

    static func save(_ schedule: ApproxSchedule) {
        guard let url else { return }
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        try? e.encode(schedule).write(to: url, options: .atomic)
    }

    static func load() -> ApproxSchedule? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(ApproxSchedule.self, from: data)
    }
}

/// Aylık imsakiye için yaklaşık takvimi yükler. Hata sessizdir: çevrimdışıyken ekran mevcut
/// (Diyanet-birebir) davranışına döner.
@MainActor
final class ApproxCalendarStore: ObservableObject {
    @Published private(set) var schedule: ApproxSchedule?
    private let provider: AladhanProvider
    private var inFlight = false

    init(provider: AladhanProvider = AladhanProvider()) {
        self.provider = provider
        self.schedule = ApproxCache.load()
    }

    func ensure(for location: SavedLocation) async {
        // Koordinatsız konumda hesap yapılamaz; ekran yalnızca kesin veriyi gösterir.
        guard let lat = location.latitude, let lon = location.longitude else { return }
        guard !inFlight, ApproxCalendar.needsRefresh(schedule, latitude: lat, longitude: lon) else { return }
        inFlight = true
        defer { inFlight = false }

        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        let margin = ApproxSafetyMargin.minutes
        guard let current = try? await provider.fetchYear(
            latitude: lat, longitude: lon, year: year, safetyMinutes: margin) else { return }
        // Gelecek yıl (Ocak-Şubat/Ramazan görünsün diye) en iyi çaba; başarısızsa mevcut yıl yeter.
        let next = try? await provider.fetchYear(
            latitude: lat, longitude: lon, year: year + 1, safetyMinutes: margin)

        let result = ApproxSchedule(
            placeName: location.name, latitude: lat, longitude: lon,
            timeZoneIdentifier: current.timeZone.identifier, fetchedAt: Date(),
            days: current.days + (next?.days ?? []))
        ApproxCache.save(result)
        schedule = result
    }
}
