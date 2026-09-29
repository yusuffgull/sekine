import Foundation

struct DiyanetCountry: Decodable, Identifiable, Hashable {
    let UlkeAdi: String     // Türkçe ad — Türkiye storefront'unda gösterilir
    let UlkeAdiEn: String   // İngilizce ad — GPS ülke eşleştirmesi için (bkz. `match`)
    let UlkeID: String
    var id: String { UlkeID }
    var name: String { UlkeAdi }
}

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

/// Diyanet ülke/il/ilçe dizini (picker için). Listeler nadiren değişir → bellek cache.
/// Türkiye dışındaki ülkeler de aynı `ezanvakti.emushaf.net` servisinden gelir — ayrı
/// bir kaynak/entegrasyon gerekmez, yalnızca ülke seçimi eklenmesi yeterlidir.
@MainActor
final class DiyanetDirectory: ObservableObject {
    /// Varsayılan/hızlı seçim: uygulamanın asıl kitlesi Türkiye'de. Onboarding ve
    /// mevcut kayıtlı konumlar (ülke bilgisi taşımayan eski `SavedLocation`'lar, bkz.
    /// `resolveAndMatchDiyanetLocation`) bu değere düşer.
    nonisolated static let turkeyCountryID = "2"

    private var cachedCountries: [DiyanetCountry]?
    private var cityCache: [String: [DiyanetCity]] = [:]
    private var districtCache: [String: [DiyanetDistrict]] = [:]

    func countries() async throws -> [DiyanetCountry] {
        if let cachedCountries { return cachedCountries }
        let url = URL(string: "\(DiyanetProvider.baseURL)/ulkeler")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let list = try JSONDecoder().decode([DiyanetCountry].self, from: data)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        cachedCountries = list
        return list
    }

    func cities(countryID: String = DiyanetDirectory.turkeyCountryID) async throws -> [DiyanetCity] {
        if let cached = cityCache[countryID] { return cached }
        let url = URL(string: "\(DiyanetProvider.baseURL)/sehirler/\(countryID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let list = try JSONDecoder().decode([DiyanetCity].self, from: data)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        cityCache[countryID] = list
        return list
    }

    func districts(cityID: String) async throws -> [DiyanetDistrict] {
        if let cached = districtCache[cityID] { return cached }
        let url = URL(string: "\(DiyanetProvider.baseURL)/ilceler/\(cityID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let dtos = try JSONDecoder().decode([DiyanetDistrictDTO].self, from: data)
        // Ad düzeltme/alias tablosu (`LocationOverrides.json`) yalnızca Türkiye ilçeleri
        // için dolu; yurt dışı şehirlerde bu tablo boş dönüp ham (yalnızca capitalize
        // edilmiş) adlar kullanılır — zararsız, IlceID zaten API'den doğru geliyor.
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

    /// GPS'ten gelen il/ilçe adını, verilen ülke içinde Diyanet listesiyle eşleştirir
    /// (Türkçe-duyarlı normalize). `countryID` verilmezse Türkiye varsayılır — geriye
    /// dönük uyumlu (eski çağıranlar/testler).
    func match(
        cityName: String?, districtName: String?,
        countryID: String = DiyanetDirectory.turkeyCountryID
    ) async -> (city: DiyanetCity, district: DiyanetDistrict)? {
        guard let cityName else { return nil }
        guard let cities = try? await cities(countryID: countryID) else { return nil }
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

    /// GPS'in verdiği ISO ülke koduna (`CLPlacemark.isoCountryCode`, ör. "DE") karşılık
    /// gelen Diyanet ülke kaydını bulur. Diyanet ISO kodu değil İngilizce ülke ADI
    /// tutuyor (`UlkeAdiEn`), bu yüzden ISO kodu önce `Locale` ile İngilizce ada
    /// çevrilip normalize edilerek karşılaştırılıyor. Eşleşme yoksa `nil` — çağıran
    /// taraf (bkz. `LocationManager.resolveAndMatchDiyanetLocation`) Türkiye'ye
    /// SESSİZCE düşmez, `matched: false` ile "hesaplanan vakit"e geçer.
    func country(forISOCode isoCode: String?) async -> DiyanetCountry? {
        guard let isoCode,
              let englishName = Locale(identifier: "en_US").localizedString(forRegionCode: isoCode)
        else { return nil }
        guard let countries = try? await countries() else { return nil }
        let target = Self.norm(englishName)
        return countries.first(where: { Self.norm($0.UlkeAdiEn) == target })
            ?? countries.first(where: { Self.norm($0.UlkeAdiEn).contains(target) || target.contains(Self.norm($0.UlkeAdiEn)) })
    }

    /// Türkçe karakter + boşluk normalize (İ→i, büyük/küçük, aksan). İngilizce ülke
    /// adları için de zararsız (diacritic'siz zaten), tek fonksiyon paylaşılıyor.
    static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
