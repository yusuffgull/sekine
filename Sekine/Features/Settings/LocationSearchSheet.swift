import SwiftUI

/// Diyanet il → ilçe seçim sayfası. İlçe ID'si birebir Diyanet vakitleri için gerekir.
/// Seçilen ilçe ayrıca coğrafi olarak çözülür (kıble + fallback için koordinat).
struct LocationSearchSheet: View {
    @EnvironmentObject private var location: LocationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var directory = DiyanetDirectory()

    let onSelect: (SavedLocation) -> Void

    @State private var cities: [DiyanetCity] = []
    @State private var districts: [DiyanetDistrict] = []
    @State private var selectedCity: DiyanetCity?
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if let city = selectedCity {
                    districtList(for: city)
                } else {
                    cityList
                }
            }
            .navigationTitle(selectedCity == nil ? "İl Seçin" : selectedCity!.name.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if selectedCity == nil {
                        Button("Kapat") { dismiss() }
                    } else {
                        Button("Geri") { selectedCity = nil; query = "" }
                    }
                }
            }
            .task { await loadCities() }
        }
    }

    private var cityList: some View {
        List {
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

    private func loadCities() async {
        guard cities.isEmpty else { return }
        isLoading = true; errorText = nil
        do { cities = try await directory.cities() }
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
        let results = await location.search("\(district.name), \(city.name), Türkiye")
        let coord = results.first
        let saved = SavedLocation(
            name: name,
            latitude: coord?.latitude ?? 39.0,
            longitude: coord?.longitude ?? 35.0,
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
}
