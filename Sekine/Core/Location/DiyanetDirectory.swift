import Foundation

struct DiyanetCity: Decodable, Identifiable, Hashable {
    let SehirAdi: String
    let SehirID: String
    var id: String { SehirID }
    var name: String { SehirAdi }
}

struct DiyanetDistrict: Identifiable, Hashable {
    /// Diyanet vakit ID'si (alias ilçeler merkez ID'sine işaret eder).
    let IlceID: String
    /// Görüntülenecek düzeltilmiş Türkçe ad.
    let name: String
    /// Alias'lar aynı IlceID'yi paylaşabildiği için liste kimliği ada göre benzersizdir.
    var id: String { "\(IlceID)|\(name)" }
}

/// API ham cevabı (ad düzeltmesi/alias uygulanmadan önce).
struct DiyanetDistrictDTO: Decodable {
    let IlceAdi: String
    let IlceID: String
}

/// Bundle'lı yerel düzeltme tablosu: emushaf verisindeki ASCII-hasarlı ilçe adlarını
/// doğru Türkçe'ye çevirir ve eksik idari ilçeleri (yalnızca vakitleri birebir aynı
/// olan metropoller) merkez ID'sine bağlar. Sadece GÖRÜNEN ad + seçilebilirlik etkilenir;
/// IlceID (dolayısıyla vakit) değişmez.
private struct LocationOverrides: Decodable {
    let nameFixes: [String: String]
    let aliasesByCity: [String: [Alias]]
    struct Alias: Decodable { let name: String; let targetID: String }

    static let shared: LocationOverrides = {
        guard let url = Bundle.main.url(forResource: "LocationOverrides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(LocationOverrides.self, from: data)
        else { return LocationOverrides(nameFixes: [:], aliasesByCity: [:]) }
        return decoded
    }()
}

/// Diyanet il/ilçe dizini (picker için). Listeler nadiren değişir → bellek + disk cache.
@MainActor
final class DiyanetDirectory: ObservableObject {
    private var cachedCities: [DiyanetCity]?
    private var districtCache: [String: [DiyanetDistrict]] = [:]

    func cities() async throws -> [DiyanetCity] {
        if let cachedCities { return cachedCities }
        let url = URL(string: "\(DiyanetProvider.baseURL)/sehirler/\(DiyanetProvider.countryID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let list = try JSONDecoder().decode([DiyanetCity].self, from: data)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        cachedCities = list
        return list
    }

    func districts(cityID: String) async throws -> [DiyanetDistrict] {
        if let cached = districtCache[cityID] { return cached }
        let url = URL(string: "\(DiyanetProvider.baseURL)/ilceler/\(cityID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let dtos = try JSONDecoder().decode([DiyanetDistrictDTO].self, from: data)
        let list = Self.applyingOverrides(dtos, cityID: cityID)
        districtCache[cityID] = list
        return list
    }

    /// Ad düzeltmesi + eksik ilçe alias'larını uygular, ada göre sıralar. Saf (ağsız) →
    /// birim testi yapılabilir. Sadece görünen ad/seçilebilirlik; IlceID değişmez.
    nonisolated static func applyingOverrides(_ dtos: [DiyanetDistrictDTO], cityID: String) -> [DiyanetDistrict] {
        let overrides = LocationOverrides.shared
        var list = dtos.map { dto in
            DiyanetDistrict(
                IlceID: dto.IlceID,
                name: overrides.nameFixes[dto.IlceID]
                    ?? dto.IlceAdi.capitalized(with: Locale(identifier: "tr_TR")))
        }
        if let aliases = overrides.aliasesByCity[cityID] {
            list += aliases.map { DiyanetDistrict(IlceID: $0.targetID, name: $0.name) }
        }
        list.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        return list
    }

    /// GPS'ten gelen il/ilçe adını Diyanet listesiyle eşleştir (Türkçe-duyarlı normalize).
    func match(cityName: String?, districtName: String?) async -> (city: DiyanetCity, district: DiyanetDistrict)? {
        guard let cityName else { return nil }
        guard let cities = try? await cities() else { return nil }
        guard let city = cities.first(where: { Self.norm($0.name) == Self.norm(cityName) })
            ?? cities.first(where: { Self.norm(cityName).contains(Self.norm($0.name)) })
        else { return nil }

        guard let districts = try? await districts(cityID: city.SehirID) else { return nil }
        let target = districtName ?? cityName
        let district = districts.first(where: { Self.norm($0.name) == Self.norm(target) })
            ?? districts.first(where: { Self.norm($0.name) == Self.norm(cityName) })
            ?? districts.first(where: { Self.norm($0.name).contains(Self.norm(city.name)) })
        guard let district else { return nil }
        return (city, district)
    }

    /// Türkçe karakter + boşluk normalize (İ→i, büyük/küçük, aksan).
    static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
