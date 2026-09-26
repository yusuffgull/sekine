import SwiftUI

/// Diyanet ülke → il → ilçe seçim sayfası. İlçe ID'si birebir Diyanet vakitleri için
/// gerekir. Seçilen ilçe ayrıca coğrafi olarak çözülür (kıble + fallback için koordinat).
/// Varsayılan ülke Türkiye (uygulamanın asıl kitlesi) — değiştirmek isteyen kullanıcı
/// üst kısımdaki "Değiştir"e dokunur, aksi halde ek bir adım eklenmez.
struct LocationSearchSheet: View {
    @EnvironmentObject private var location: LocationManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var directory: DiyanetDirectory

    let onSelect: (SavedLocation) -> Void

    @State private var countries: [DiyanetCountry] = []
    @State private var selectedCountry: DiyanetCountry?
    @State private var isPickingCountry = false
    @State private var cities: [DiyanetCity] = []
    @State private var districts: [DiyanetDistrict] = []
    @State private var selectedCity: DiyanetCity?
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if isPickingCountry {
                    countryList
                } else if let city = selectedCity {
                    districtList(for: city)
                } else {
                    cityList
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isPickingCountry {
                        Button("Vazgeç") { isPickingCountry = false; query = "" }
                    } else if selectedCity == nil {
                        Button("Kapat") { dismiss() }
                    } else {
                        Button("Geri") { selectedCity = nil; query = "" }
                    }
                }
            }
            .task { await loadCountriesAndDefaultCities() }
        }
    }

    private var navigationTitle: String {
        if isPickingCountry { return "Ülke Seçin" }
        if let city = selectedCity { return city.name.capitalized(with: Locale(identifier: "tr_TR")) }
        return "İl Seçin"
    }

    private var cityList: some View {
        List {
            if let selectedCountry {
                Button {
                    query = ""
                    isPickingCountry = true
                } label: {
                    HStack {
                        Text("Ülke").foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text(selectedCountry.name.capitalized(with: Locale(identifier: "tr_TR")))
                            .foregroundStyle(Palette.textPrimary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }
            if isLoading && cities.isEmpty {
                HStack { ProgressView(); Text("İller yükleniyor…").foregroundStyle(Palette.textSecondary) }
            }
            ForEach(filtered(cities.map(\.name), from: cities)) { city in
                Button {
                    selectedCity = city
                    query = ""
                    Task { await loadDistricts(city) }
                } label: {
                    HStack {
                        Text(city.name.capitalized(with: Locale(identifier: "tr_TR")))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "İl ara")
    }

    private var countryList: some View {
        List {
            ForEach(filteredCountries) { country in
                Button {
                    selectedCountry = country
                    isPickingCountry = false
                    query = ""
                    Task { await loadCities(for: country) }
                } label: {
                    HStack {
                        Text(country.name.capitalized(with: Locale(identifier: "tr_TR")))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        if country.UlkeID == selectedCountry?.UlkeID {
                            Image(systemName: "checkmark").foregroundStyle(Palette.accent)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Ülke ara")
    }

    private func districtList(for city: DiyanetCity) -> some View {
        List {
            if isLoading && districts.isEmpty {
                HStack { ProgressView(); Text("İlçeler yükleniyor…").foregroundStyle(Palette.textSecondary) }
            }
            ForEach(filteredDistricts) { district in
                Button {
                    Task { await select(city: city, district: district) }
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(Palette.accent)
                        Text(district.name.capitalized(with: Locale(identifier: "tr_TR")))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "İlçe ara")
    }

    // MARK: - Data

    private func loadCountriesAndDefaultCities() async {
        guard countries.isEmpty else { return }
        isLoading = true; errorText = nil
        do {
            countries = try await directory.countries()
            selectedCountry = countries.first { $0.UlkeID == DiyanetDirectory.turkeyCountryID }
                ?? countries.first
        } catch {
            errorText = "Ülke listesi yüklenemedi. İnternet bağlantınızı kontrol edin."
        }
        if let selectedCountry {
            await loadCities(for: selectedCountry)
        }
        isLoading = false
    }

    private func loadCities(for country: DiyanetCountry) async {
        cities = []
        isLoading = true; errorText = nil
        do { cities = try await directory.cities(countryID: country.UlkeID) }
        catch { errorText = "İl listesi yüklenemedi. İnternet bağlantınızı kontrol edin." }
        isLoading = false
    }

    private func loadDistricts(_ city: DiyanetCity) async {
        districts = []
        isLoading = true; errorText = nil
        do { districts = try await directory.districts(cityID: city.SehirID) }
        catch { errorText = "İlçe listesi yüklenemedi." }
        isLoading = false
    }

    private func select(city: DiyanetCity, district: DiyanetDistrict) async {
        let name = "\(district.name.capitalized(with: Locale(identifier: "tr_TR"))), \(city.name.capitalized(with: Locale(identifier: "tr_TR")))"
        // Kıble + fallback için koordinat çöz (Diyanet vakti için gerekmez).
        // Çözülemezse koordinat nil kalır; placeholder saklanmaz.
        let countryName = selectedCountry?.name.capitalized(with: Locale(identifier: "tr_TR"))
        let coord = await location.geocodeCoordinate(district: district.name, city: city.name, countryName: countryName)
        let saved = SavedLocation(
            name: name,
            latitude: coord?.latitude,
            longitude: coord?.longitude,
            diyanetDistrictID: district.IlceID)
        onSelect(saved)
        dismiss()
    }

    // MARK: - Filtering

    private var filteredDistricts: [DiyanetDistrict] {
        guard !query.isEmpty else { return districts }
        let q = DiyanetDirectory.norm(query)
        return districts.filter { DiyanetDirectory.norm($0.name).contains(q) }
    }

    private func filtered(_ names: [String], from source: [DiyanetCity]) -> [DiyanetCity] {
        guard !query.isEmpty else { return source }
        let q = DiyanetDirectory.norm(query)
        return source.filter { DiyanetDirectory.norm($0.name).contains(q) }
    }

    private var filteredCountries: [DiyanetCountry] {
        guard !query.isEmpty else { return countries }
        let q = DiyanetDirectory.norm(query)
        return countries.filter { DiyanetDirectory.norm($0.name).contains(q) }
    }
}
