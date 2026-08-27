import Foundation

/// App Store'da kurulu sürümden daha yeni bir sürüm olup olmadığını, Apple'ın herkese
/// açık iTunes Lookup API'siyle kontrol eder. Salt okunur/bilgilendirici — kullanıcı
/// verisi göndermez, uygulamayı engellemez. Yalnızca Ayarlar ekranından tetiklenir.
struct AppUpdateChecker {
    struct UpdateInfo: Equatable {
        let latestVersion: String
        let appStoreURL: URL
    }

    static let appleID = "6796900944"
    static let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(appleID)&country=tr")!
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id\(appleID)")!

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func checkForUpdate(currentVersion: String = AppUpdateChecker.currentInstalledVersion) async throws -> UpdateInfo? {
        let data: Data
        do {
            (data, _) = try await session.data(from: Self.lookupURL)
        } catch {
            throw AppUpdateCheckError.network(underlying: error)
        }

        let decoded: LookupResponse
        do {
            decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
        } catch {
            throw AppUpdateCheckError.decoding
        }

        guard let result = decoded.results.first else {
            throw AppUpdateCheckError.emptyResult
        }

        guard Self.isNewer(result.version, than: currentVersion) else { return nil }
        return UpdateInfo(latestVersion: result.version, appStoreURL: Self.appStoreURL)
    }

    static var currentInstalledVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Nokta ayraçlı sayısal karşılaştırma ("1.10" > "1.6") — string karşılaştırma değil.
    static func isNewer(_ candidate: String, than installed: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = parts(candidate), b = parts(installed)
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

private struct LookupResponse: Decodable {
    struct Result: Decodable { let version: String }
    let results: [Result]
}

enum AppUpdateCheckError: Error, LocalizedError {
    case network(underlying: Error)
    case decoding
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .network: return "Güncelleme kontrol edilemedi."
        case .decoding: return "Sürüm bilgisi çözümlenemedi."
        case .emptyResult: return "Uygulama App Store'da bulunamadı."
        }
    }
}
