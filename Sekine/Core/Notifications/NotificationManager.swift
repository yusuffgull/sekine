import Foundation
import UserNotifications

/// Bildirim izni ve durumunu yönetir. Rakiplerin "bildirim çalışmıyor"
/// şikayetine karşı: izin durumu UI'da net gösterilir, kapalıysa kullanıcı
/// Ayarlar'a yönlendirilir.
@MainActor
final class NotificationManager: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// İzin ister. Zaten belirlenmişse durumu tazeler.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }
}
