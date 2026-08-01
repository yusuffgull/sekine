import Foundation

/// Ücretli özellik kapısı. v1: her zaman false (uygulama tamamen ücretsiz + reklamsız).
/// v1.1: StoreKit 2 aboneliği ile "tam ezan" (peşpeşe bildirim) açılır — bu protokol
/// uygulamanın geri kalanına dokunmadan gerçek bir mağaza uygulamasıyla değiştirilir.
protocol PremiumProviding: Sendable {
    var isPremium: Bool { get }
}

/// v1 varsayılanı.
struct FreeTierGate: PremiumProviding {
    var isPremium: Bool { false }
}
