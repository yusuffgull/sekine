import Foundation

/// Uygulamanın vakit beyni: cache'i yükler, gerektiğinde indirir (Diyanet → Aladhan →
/// lokal fallback zinciri), diske yazar ve bildirimleri yeniden zamanlar.
@MainActor
final class PrayerTimeStore: ObservableObject {
    @Published private(set) var schedule: PrayerSchedule?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Öncelik sırası: birebir Diyanet → Aladhan (yaklaşık, konum) → lokal hesap (çevrimdışı).
    private let providers: [PrayerTimeProvider]
    private let scheduler = RollingScheduler()

    init(providers: [PrayerTimeProvider] = [
        DiyanetProvider(), AladhanProvider(), LocalCalculationProvider()
    ]) {
        self.providers = providers
        self.schedule = PrayerCache.load()
    }

    // MARK: - Türetilmiş görünümler

    var today: PrayerDay? { schedule?.day(containing: Date()) }
    var nextTime: PrayerTime? { schedule?.nextTime(after: Date()) }
    var currentTime: PrayerTime? { schedule?.currentTime(at: Date()) }

    // MARK: - Veri yaşam döngüsü

    func ensureData(for location: SavedLocation, settings: AppSettings) async {
        if needsRefresh(for: location) {
            await refresh(location: location, settings: settings)
        } else {
            await rescheduleNotifications(settings: settings)
        }
    }

    func refresh(location: SavedLocation, settings: AppSettings) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var lastError: Error?
        for provider in providers where provider.canHandle(location) {
            do {
                let result = try await provider.fetchSchedule(for: location)
                apply(result)
                // Diyanet dışı bir kaynağa düştüysek kullanıcıyı bilgilendir.
                if result.source != "diyanet" {
                    errorMessage = "Diyanet vakitleri alınamadı; yaklaşık vakitler gösteriliyor. Bağlantı gelince güncellenecek."
                }
                await rescheduleNotifications(settings: settings)
                return
            } catch {
                lastError = error
                continue
            }
        }
        errorMessage = (lastError as? PrayerProviderError)?.errorDescription
            ?? "Vakitler yüklenemedi. İnternet bağlantınızı kontrol edin."
        await rescheduleNotifications(settings: settings)
    }

    func rescheduleNotifications(settings: AppSettings) async {
        guard let schedule else { return }
        let enabled = Set(Prayer.ordered.filter { settings.isNotificationEnabled(for: $0) })
        let config = SchedulerConfig(
            enabledPrayers: enabled,
            sound: NotificationSound(rawValue: settings.notificationSound) ?? .default,
            silent: settings.silentNotifications,
            preReminderMinutes: settings.preReminderMinutes,
            breakThroughFocus: settings.breakThroughFocus)
        await scheduler.reschedule(from: schedule, config: config)
    }

    // MARK: - Yardımcılar

    private func apply(_ schedule: PrayerSchedule) {
        self.schedule = schedule
        PrayerCache.save(schedule)
    }

    /// Yeniden indirme gerekiyor mu? (konum değişti, kaynak yükseltilebilir, kapsam bitiyor)
    private func needsRefresh(for location: SavedLocation) -> Bool {
        guard let schedule else { return true }
        let sameLocation = abs(schedule.latitude - location.latitude) < 0.01
            && abs(schedule.longitude - location.longitude) < 0.01
        if !sameLocation { return true }
        // Diyanet ID'si var ama cache Diyanet değilse, birebir veriye yükselt.
        if location.diyanetDistrictID != nil, schedule.source != "diyanet" { return true }
        // Diyanet ~1 aylık pencere döner; kapsam 12 günün altına düşünce tazele
        // (bildirim penceresi ~12 gün → hep dolu kalsın).
        guard let lastDay = schedule.days.map(\.dayStart).max() else { return true }
        return lastDay.timeIntervalSinceNow < 12 * 24 * 3600
    }
}
