import Foundation

/// Uygulamanın vakit beyni: cache'i yükler, gerektiğinde indirir (Aladhan →
/// fallback), diske yazar ve bildirimleri yeniden zamanlar.
@MainActor
final class PrayerTimeStore: ObservableObject {
    @Published private(set) var schedule: PrayerSchedule?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let primary: PrayerTimeProvider
    private let fallback: PrayerTimeProvider
    private let scheduler = RollingScheduler()

    init(primary: PrayerTimeProvider = AladhanProvider(),
         fallback: PrayerTimeProvider = LocalCalculationProvider()) {
        self.primary = primary
        self.fallback = fallback
        self.schedule = PrayerCache.load()
    }

    // MARK: - Türetilmiş görünümler

    var today: PrayerDay? { schedule?.day(containing: Date()) }
    var nextTime: PrayerTime? { schedule?.nextTime(after: Date()) }
    var currentTime: PrayerTime? { schedule?.currentTime(at: Date()) }

    // MARK: - Veri yaşam döngüsü

    /// Cache seçili konumu kapsıyorsa dokunmaz; değilse indirir. App açılışında çağrılır.
    func ensureData(for location: SavedLocation, settings: AppSettings) async {
        if needsRefresh(for: location) {
            await refresh(location: location, settings: settings)
        } else {
            await rescheduleNotifications(settings: settings)
        }
    }

    /// Zorla yeniden indir (konum değişimi / kullanıcı yenilemesi).
    func refresh(location: SavedLocation, settings: AppSettings) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        do {
            let result = try await primary.fetchSchedule(
                latitude: location.latitude,
                longitude: location.longitude,
                placeName: location.name,
                year: year)
            apply(result)
        } catch {
            // Ağ hatası → yaklaşık lokal hesapla (uygulama boş kalmasın), kullanıcıyı bilgilendir.
            if let local = try? await fallback.fetchSchedule(
                latitude: location.latitude,
                longitude: location.longitude,
                placeName: location.name,
                year: year) {
                apply(local)
                errorMessage = "Vakitler indirilemedi; yaklaşık hesaplama gösteriliyor. Bağlantı gelince güncellenecek."
            } else {
                errorMessage = (error as? PrayerProviderError)?.errorDescription
                    ?? "Vakitler yüklenemedi."
            }
        }
        await rescheduleNotifications(settings: settings)
    }

    /// Ayarlar (açık vakitler / ses) değişince bildirimleri yeniden kur.
    func rescheduleNotifications(settings: AppSettings) async {
        guard let schedule else { return }
        let enabled = Set(Prayer.ordered.filter { settings.isNotificationEnabled(for: $0) })
        let config = SchedulerConfig(
            enabledPrayers: enabled,
            sound: NotificationSound(rawValue: settings.notificationSound) ?? .default,
            silent: settings.silentNotifications,
            preReminderMinutes: settings.preReminderMinutes)
        await scheduler.reschedule(from: schedule, config: config)
    }

    // MARK: - Yardımcılar

    private func apply(_ schedule: PrayerSchedule) {
        self.schedule = schedule
        PrayerCache.save(schedule)
    }

    /// Yeniden indirme gerekiyor mu? (konum değişti, veri yok, ya da kapsam bitiyor)
    private func needsRefresh(for location: SavedLocation) -> Bool {
        guard let schedule else { return true }
        let sameLocation = abs(schedule.latitude - location.latitude) < 0.01
            && abs(schedule.longitude - location.longitude) < 0.01
        if !sameLocation { return true }
        // Kapsam son 20 günden aza düştüyse tazele (yıl dönümü / uzun kullanım).
        guard let lastDay = schedule.days.map(\.dayStart).max() else { return true }
        return lastDay.timeIntervalSinceNow < 20 * 24 * 3600
    }
}
