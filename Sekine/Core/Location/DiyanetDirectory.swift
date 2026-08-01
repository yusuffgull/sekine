import Foundation

struct DiyanetCity: Decodable, Identifiable, Hashable {
    let SehirAdi: String
    let SehirID: String
    var id: String { SehirID }
    var name: String { SehirAdi }
}

struct DiyanetDistrict: Decodable, Identifiable, Hashable {
    let IlceAdi: String
    let IlceID: String
    var id: String { IlceID }
    var name: String { IlceAdi }
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
        let list = try JSONDecoder().decode([DiyanetDistrict].self, from: data)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        districtCache[cityID] = list
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
