import Foundation

/// Diyanet'in beş vakti + güneş (kerahat/sabah bilgisi için gösterilir).
enum Prayer: String, Codable, CaseIterable, Identifiable, Sendable {
    case fajr      // İmsak
    case sunrise   // Güneş
    case dhuhr     // Öğle
    case asr       // İkindi
    case maghrib   // Akşam
    case isha      // Yatsı

    var id: String { rawValue }

    /// Türkçe (Diyanet) vakit adı.
    var displayName: String {
        switch self {
        case .fajr: return "İmsak"
        case .sunrise: return "Güneş"
        case .dhuhr: return "Öğle"
        case .asr: return "İkindi"
        case .maghrib: return "Akşam"
        case .isha: return "Yatsı"
        }
    }

    var systemImage: String {
        switch self {
        case .fajr: return "moon.stars.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.fill"
        }
    }

    /// Güneş bir namaz vakti değildir; varsayılan bildirim listesine girmez.
    var isNotifiable: Bool { self != .sunrise }

    /// Sıralı gösterim (İmsak → Yatsı).
    static let ordered: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
}
