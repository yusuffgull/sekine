import Foundation

/// Vakit planını cihazda saklar (app group → widget de okur).
/// App group provisioning yoksa Documents dizinine düşer, böylece geliştirme
/// build'leri de çalışır.
enum PrayerCache {

    private static var storeURL: URL? {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent(AppGroup.scheduleFileName)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func save(_ schedule: PrayerSchedule) {
        guard let url = storeURL else { return }
        do {
            let data = try encoder.encode(schedule)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("PrayerCache save failed: \(error)")
            #endif
        }
    }

    static func load() -> PrayerSchedule? {
        guard let url = storeURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PrayerSchedule.self, from: data)
    }
}
