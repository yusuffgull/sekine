import Foundation

/// Ücretli özellik kapısı. Gerçek uygulaması `Store` (StoreKit 2). Bu protokol,
/// önizleme/test'te sahte bir kapı (FreeTierGate) enjekte edebilmek için tutulur.
@MainActor
protocol PremiumProviding {
    var isPremium: Bool { get }
}

/// Önizleme/test varsayılanı (her zaman ücretsiz).
struct FreeTierGate: PremiumProviding {
    var isPremium: Bool { false }
}
