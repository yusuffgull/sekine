import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Açık"
        case .dark: return "Koyu"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum FontScale: String, CaseIterable, Identifiable {
    case normal, large, extraLarge
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .large: return "Büyük"
        case .extraLarge: return "Çok Büyük"
        }
    }
    /// Özel (sabit punto) SekineFont öğelerine uygulanan çarpan.
    var multiplier: CGFloat {
        switch self {
        case .normal: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }

    /// Varsayılan SwiftUI fontlarını (Form, liste, başlık) ölçekler. Kökte
    /// uygulanır → Ayarlar/Onboarding/Aylık dahil tüm ekranları etkiler.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .normal: return .large      // sistem varsayılanı
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        }
    }
}

/// Seçili konum. Diyanet ilçe ID'si varsa vakitler birebir Diyanet resmi verisinden
/// gelir; yoksa (ör. eşleşmeyen GPS) koordinatla Aladhan'a düşülür. lat/lng kıble ve
/// fallback için her zaman tutulur.
struct SavedLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var diyanetDistrictID: String?

    init(name: String, latitude: Double, longitude: Double, diyanetDistrictID: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.diyanetDistrictID = diyanetDistrictID
    }
}

/// Uygulama ayarları. App group defaults'ta saklanır (widget da okuyabilir).
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        self.location = Self.loadLocation(defaults)
        self.disabledPrayers = Self.loadDisabledPrayers(defaults)
        self.theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        self.fontScale = FontScale(rawValue: defaults.string(forKey: Keys.fontScale) ?? "") ?? .normal
        self.notificationSound = defaults.string(forKey: Keys.sound) ?? NotificationSound.default.rawValue
        self.silentNotifications = defaults.bool(forKey: Keys.silent)
        self.breakThroughFocus = defaults.bool(forKey: Keys.breakThroughFocus)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
        self.preReminderMinutes = defaults.object(forKey: Keys.preReminder) as? Int ?? 0
    }

    @Published var location: SavedLocation? {
        didSet {
            if let location, let data = try? JSONEncoder().encode(location) {
                defaults.set(data, forKey: Keys.location)
            } else if location == nil {
                defaults.removeObject(forKey: Keys.location)
            }
        }
    }

    /// Bildirimi KAPALI olan vakitler (varsayılan: hepsi açık, güneş hariç).
    @Published var disabledPrayers: Set<Prayer> {
        didSet {
            let raw = disabledPrayers.map(\.rawValue)
            defaults.set(raw, forKey: Keys.disabledPrayers)
        }
    }

    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var fontScale: FontScale {
        didSet { defaults.set(fontScale.rawValue, forKey: Keys.fontScale) }
    }

    @Published var notificationSound: String {
        didSet { defaults.set(notificationSound, forKey: Keys.sound) }
    }

    @Published var silentNotifications: Bool {
        didSet { defaults.set(silentNotifications, forKey: Keys.silent) }
    }

    /// Açıkken bildirimler Odak/Uyku/Rahatsız Etmeyin'i deler (opt-in, varsayılan kapalı).
    @Published var breakThroughFocus: Bool {
        didSet { defaults.set(breakThroughFocus, forKey: Keys.breakThroughFocus) }
    }

    /// Vakitten kaç dakika önce hatırlatma (0 = yalnızca vakit girişinde).
    @Published var preReminderMinutes: Int {
        didSet { defaults.set(preReminderMinutes, forKey: Keys.preReminder) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    func isNotificationEnabled(for prayer: Prayer) -> Bool {
        prayer.isNotifiable && !disabledPrayers.contains(prayer)
    }

    func setNotification(_ enabled: Bool, for prayer: Prayer) {
        if enabled { disabledPrayers.remove(prayer) }
        else { disabledPrayers.insert(prayer) }
    }

    // MARK: - Persistence helpers

    private static func loadLocation(_ d: UserDefaults) -> SavedLocation? {
        guard let data = d.data(forKey: Keys.location) else { return nil }
        return try? JSONDecoder().decode(SavedLocation.self, from: data)
    }

    private static func loadDisabledPrayers(_ d: UserDefaults) -> Set<Prayer> {
        let raw = d.stringArray(forKey: Keys.disabledPrayers) ?? []
        return Set(raw.compactMap(Prayer.init(rawValue:)))
    }

    private enum Keys {
        static let location = "settings.location"
        static let disabledPrayers = "settings.disabledPrayers"
        static let theme = "settings.theme"
        static let fontScale = "settings.fontScale"
        static let sound = "settings.sound"
        static let silent = "settings.silent"
        static let breakThroughFocus = "settings.breakThroughFocus"
        static let preReminder = "settings.preReminder"
        static let onboarded = "settings.onboarded"
    }
}
