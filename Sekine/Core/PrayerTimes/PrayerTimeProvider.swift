import Foundation

/// Vakit kaynağı soyutlaması. v1 varsayılanı Aladhan method=13 (Diyanet).
/// Submit öncesi doğrulama Aladhan'ı yetersiz bulursa, aynı protokolü uygulayan
/// bir Diyanet-resmi (awqatsalah) sağlayıcı uygulamanın geri kalanına dokunmadan
/// takılabilir. Bkz. docs/decisions.md.
protocol PrayerTimeProvider: Sendable {
    var sourceIdentifier: String { get }

    /// Verilen konum için bir yıllık planı üretir.
    func fetchSchedule(
        latitude: Double,
        longitude: Double,
        placeName: String,
        year: Int
    ) async throws -> PrayerSchedule
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
