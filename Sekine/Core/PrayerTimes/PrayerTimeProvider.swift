import Foundation

/// Vakit kaynağı soyutlaması. v1 varsayılanı Aladhan method=13 (Diyanet).
/// Submit öncesi doğrulama Aladhan'ı yetersiz bulursa, aynı protokolü uygulayan
/// bir Diyanet-resmi (awqatsalah) sağlayıcı uygulamanın geri kalanına dokunmadan
/// takılabilir. Bkz. docs/decisions.md.
protocol PrayerTimeProvider: Sendable {
    var sourceIdentifier: String { get }

    /// Bu sağlayıcı verilen konumu işleyebilir mi? (ör. Diyanet ilçe ID'si gerektirir)
    func canHandle(_ location: SavedLocation) -> Bool

    /// Verilen konum için mevcut plan penceresini üretir.
    func fetchSchedule(for location: SavedLocation) async throws -> PrayerSchedule
}

extension PrayerTimeProvider {
    func canHandle(_ location: SavedLocation) -> Bool { true }
}

enum PrayerProviderError: Error, LocalizedError {
    case network(underlying: Error)
    case decoding
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .network: return "Vakitler indirilemedi. İnternet bağlantınızı kontrol edin."
        case .decoding: return "Vakit verisi çözümlenemedi."
        case .emptyResult: return "Bu konum için vakit bulunamadı."
        }
    }
}
