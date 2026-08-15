import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BackgroundRefresh.register()
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Uygulama önplandayken bir vakit bildirimi tetiklenirse: banner+ses göster
    /// VE pencereyi tazele (bir bildirim "tükendiğinde" yerine yenisi girsin).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await BackgroundRefresh.rescheduleFromCache()
        return [.banner, .sound, .list]
    }

    /// Kullanıcı bir bildirime dokunduğunda da pencereyi tazele (ek tetikleyici).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await BackgroundRefresh.rescheduleFromCache()
    }
}
