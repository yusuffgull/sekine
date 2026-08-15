import SwiftUI

/// Premium renk temaları. Yalnızca vurgu renklerini (accent + gold) değiştirir; sıcak
/// nötr zemin/metin her temada korunur → tutarlı, güvenli estetik. `zumrut` ücretsiz.
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

    /// Ücretsiz varsayılan dışındaki temalar premium.
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

    /// Aktif satır/kart yumuşak zemini — temaya uyumlu hafif tint (light, dark).
    var accentSoft: (UInt, UInt) {
        switch self {
        case .zumrut:     return (0xEAF2EE, 0x24322B)
        case .geceMavisi: return (0xE7EEF6, 0x1E2A38)
        case .visne:      return (0xF4E9EB, 0x33232A)
        case .colAltini:  return (0xF3ECDD, 0x2E2718)
        case .menekse:    return (0xEFEAF6, 0x271E33)
        }
    }

    /// Seçili tema (app-group defaults'tan; widget/arka plan da okuyabilir).
    static var current: ColorTheme {
        let raw = (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
            .string(forKey: "settings.colorTheme") ?? ""
        return ColorTheme(rawValue: raw) ?? .zumrut
    }
}

/// Sekine tasarım token'ları. Hardcode renk/font yasağı (CLAUDE.md): tüm renkler
/// ve ölçüler buradan gelir. Sıcak, sakin, dini bir estetik; koyu/açık tema uyumlu.
/// Vurgu renkleri seçili `ColorTheme`'den gelir (81 çağrı yeri değişmez).
enum Palette {
    /// Ana vurgu — seçili temaya göre.
    static var accent: Color { dynamic(light: hex(ColorTheme.current.accent.0),
                                       dark: hex(ColorTheme.current.accent.1)) }
    /// İkincil vurgu (altın) — seçili temaya göre.
    static var gold: Color { dynamic(light: hex(ColorTheme.current.gold.0),
                                     dark: hex(ColorTheme.current.gold.1)) }

    static let background = dynamic(light: hex(0xF7F4EE), dark: hex(0x12140F))
    static let card = dynamic(light: hex(0xFFFFFF), dark: hex(0x1D211A))
    /// Aktif satır zemini — seçili temaya uyumlu.
    static var cardActive: Color { dynamic(light: hex(ColorTheme.current.accentSoft.0),
                                           dark: hex(ColorTheme.current.accentSoft.1)) }

    static let textPrimary = dynamic(light: hex(0x1A1C18), dark: hex(0xF2F1EA))
    static let textSecondary = dynamic(light: hex(0x5C5F57), dark: hex(0xB6B9AE))
    static let separator = dynamic(light: hex(0xE3DED3), dark: hex(0x2C2F27))

    // MARK: helpers
    private static func hex(_ value: UInt) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1)
    }
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Ölçek-duyarlı tipografi. Yaşlı kullanıcı için ayarlardan büyütülebilir;
/// ayrıca Dynamic Type'a saygı duyar.
struct SekineFont {
    static func countdown(_ scale: FontScale) -> Font {
        .system(size: 56 * scale.multiplier, weight: .bold, design: .rounded)
            .monospacedDigit()
    }
    static func hugeTime(_ scale: FontScale) -> Font {
        .system(size: 40 * scale.multiplier, weight: .semibold, design: .rounded)
    }
    static func title(_ scale: FontScale) -> Font {
        .system(size: 22 * scale.multiplier, weight: .semibold, design: .rounded)
    }
    static func row(_ scale: FontScale) -> Font {
        .system(size: 20 * scale.multiplier, weight: .medium, design: .rounded)
    }
    static func caption(_ scale: FontScale) -> Font {
        .system(size: 15 * scale.multiplier, weight: .regular, design: .rounded)
    }
}

extension View {
    /// Kart görünümü (yumuşak köşe, hafif gölge).
    func sekineCard(active: Bool = false) -> some View {
        self
            .background(active ? Palette.cardActive : Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(active ? Palette.accent.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
    }
}
