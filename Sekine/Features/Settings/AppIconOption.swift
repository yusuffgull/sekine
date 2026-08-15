import UIKit

/// Seçilebilir uygulama ikonları. İkisi de ücretsiz. `alternateName == nil` → birincil
/// (varsayılan) AppIcon.
enum AppIconOption: String, CaseIterable, Identifiable {
    case defaultIcon
    case cinar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultIcon: return "Gece Hilali (Varsayılan)"
        case .cinar: return "Yıldızlı Hilal"
        }
    }

    var subtitle: String? {
        switch self {
        case .defaultIcon: return nil
        case .cinar: return "Çınar'ın tasarımı 💚"
        }
    }

    /// `UIApplication.setAlternateIconName` için ad (nil = varsayılan).
    var alternateName: String? {
        switch self {
        case .defaultIcon: return nil
        case .cinar: return "AppIcon-Cinar"
        }
    }

    static var current: AppIconOption {
        let name = UIApplication.shared.alternateIconName
        return AppIconOption.allCases.first { $0.alternateName == name } ?? .defaultIcon
    }
}
