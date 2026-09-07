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

    /// Bundle'da ses dosyası mevcut mu? (Picker'da yalnızca çalışan sesler gösterilsin diye.)
    /// `.default` dosya gerektirmediği için her zaman kullanılabilir. watchOS özel ses
    /// dosyalarını desteklemediğinden, orada yalnızca `.default` kullanılabilir sayılır
    /// (bkz. `unSound(silent:)` — aynı platform ayrımı).
    var isAvailable: Bool {
        #if os(watchOS)
        return self == .default
        #else
        guard let fileName else { return true }
        return Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension,
                                withExtension: (fileName as NSString).pathExtension) != nil
        #endif
    }

    /// UNNotificationSound. Dosya bundle'da yoksa güvenli şekilde varsayılana döner.
    /// watchOS özel bildirim sesi dosyalarını desteklemiyor (`init(named:)` unavailable) —
    /// o platformda her zaman sistem varsayılanına düşülür.
    func unSound(silent: Bool) -> UNNotificationSound? {
        if silent { return nil }
        #if os(watchOS)
        return .default
        #else
        guard let fileName,
              Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension,
                              withExtension: (fileName as NSString).pathExtension) != nil
        else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
        #endif
    }
}
