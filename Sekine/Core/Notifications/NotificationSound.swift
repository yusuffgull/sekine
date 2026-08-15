import Foundation
import UserNotifications

/// Kısa bildirim sesleri (iOS bildirim sesi limiti 30 sn). Tam ezan v1'de yok
/// (v1.1 premium). Ses dosyaları Resources/Sounds içinde .caf olarak bulunur;
/// dosya yoksa sistem varsayılan sesi kullanılır.
enum NotificationSound: String, CaseIterable, Identifiable {
    case `default`
    case chime
    case ezan   // Premium: kısa ezan tonu (≤30 sn). Ses dosyası: ezan.caf.

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Varsayılan"
        case .chime: return "Hafif Çıngırak"
        case .ezan: return "Ezan"
        }
    }

    /// Premium (ücretli) ses mi? Ücretsiz kullanıcı seçemez.
    var isPremiumSound: Bool {
        switch self {
        case .default, .chime: return false
        case .ezan: return true
        }
    }

    /// Bundle'daki dosya adı (nil → sistem varsayılanı).
    var fileName: String? {
        switch self {
        case .default: return nil
        case .chime: return "chime.caf"
        case .ezan: return "ezan.caf"
        }
    }

    /// UNNotificationSound. Dosya bundle'da yoksa güvenli şekilde varsayılana döner.
    func unSound(silent: Bool) -> UNNotificationSound? {
        if silent { return nil }
        guard let fileName,
              Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension,
                              withExtension: (fileName as NSString).pathExtension) != nil
        else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}
