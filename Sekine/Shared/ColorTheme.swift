import Foundation

/// Premium renk temaları — app ve widget arasında paylaşılır (accent/gold token'ları).
/// `zumrut` ücretsiz varsayılan. Seçim app-group defaults'ta saklanır.
enum ColorTheme: String, CaseIterable, Identifiable {
    case zumrut, geceMavisi, visne, colAltini, menekse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zumrut: return "Zümrüt"
        case .geceMavisi: return "Gece Mavisi"
        case .visne: return "Vişne"
        case .colAltini: return "Çöl Altını"
        case .menekse: return "Menekşe"
        }
    }

    var isPremium: Bool { self != .zumrut }

    /// accent (light, dark)
    var accent: (UInt, UInt) {
        switch self {
        case .zumrut:     return (0x1F6E5C, 0x4FB89E)
        case .geceMavisi: return (0x2A5C8F, 0x6FA8D8)
        case .visne:      return (0x8E2D3C, 0xC96A78)
        case .colAltini:  return (0x9C6B1F, 0xD7A24B)
        case .menekse:    return (0x6A4C93, 0xA88BD0)
        }
    }

    /// gold / ikincil vurgu (light, dark)
    var gold: (UInt, UInt) {
        switch self {
        case .zumrut:     return (0xB5893C, 0xD9B76A)
        case .geceMavisi: return (0xB08A4A, 0xE0C079)
        case .visne:      return (0xB5893C, 0xD9B76A)
        case .colAltini:  return (0x7A5B2A, 0xC9A15A)
        case .menekse:    return (0xB5893C, 0xD9B76A)
        }
    }

    /// Aktif satır/kart yumuşak zemini (light, dark).
    var accentSoft: (UInt, UInt) {
        switch self {
        case .zumrut:     return (0xEAF2EE, 0x24322B)
        case .geceMavisi: return (0xE7EEF6, 0x1E2A38)
        case .visne:      return (0xF4E9EB, 0x33232A)
        case .colAltini:  return (0xF3ECDD, 0x2E2718)
        case .menekse:    return (0xEFEAF6, 0x271E33)
        }
    }

    static var current: ColorTheme {
        let raw = (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
            .string(forKey: "settings.colorTheme") ?? ""
        return ColorTheme(rawValue: raw) ?? .zumrut
    }
}
