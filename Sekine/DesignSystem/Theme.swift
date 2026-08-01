import SwiftUI

/// Sekine tasarım token'ları. Hardcode renk/font yasağı (CLAUDE.md): tüm renkler
/// ve ölçüler buradan gelir. Sıcak, sakin, dini bir estetik; koyu/açık tema uyumlu.
enum Palette {
    /// Koyu yeşil — huzur/maneviyat çağrışımı, ana vurgu.
    static let accent = dynamic(light: hex(0x1F6E5C), dark: hex(0x4FB89E))
    /// Yumuşak altın — ikincil vurgu (sonraki vakit rozeti vb.).
    static let gold = dynamic(light: hex(0xB5893C), dark: hex(0xD9B76A))

    static let background = dynamic(light: hex(0xF7F4EE), dark: hex(0x12140F))
    static let card = dynamic(light: hex(0xFFFFFF), dark: hex(0x1D211A))
    static let cardActive = dynamic(light: hex(0xEAF2EE), dark: hex(0x24322B))

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
