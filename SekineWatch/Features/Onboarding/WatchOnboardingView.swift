import SwiftUI

struct WatchOnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var notifications: NotificationManager

    @StateObject private var directory = DiyanetDirectory()
    @State private var isResolving = false
    @State private var errorText: String?
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                Text("Sekine")
                    .font(.headline)
                Text("Namaz vakitleri için konumunuzu seçin.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let errorText {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    if isResolving {
                        ProgressView()
                    } else {
                        Text("Konumumu Kullan")
                    }
                }
                .disabled(isResolving)

                Button("İl / İlçe Seç") { showPicker = true }
            }
            .padding()
            .sheet(isPresented: $showPicker) {
                WatchCityPickerView(directory: directory) { place in
                    Task { await finish(with: place) }
                    showPicker = false
                }
            }
        }
    }

    private func useCurrentLocation() async {
        isResolving = true
        errorText = nil
        defer { isResolving = false }
        location.requestPermission()
        do {
            let resolved = try await location.resolveCurrentLocation()
            var place = resolved.location
            // GPS'in verdiği ülkede ara (yurt dışı kullanıcı sessizce Türkiye'de aranmasın).
            let countryID = await directory.country(forISOCode: resolved.isoCountryCode)?.UlkeID
                ?? DiyanetDirectory.turkeyCountryID
            if let match = await directory.match(
                cityName: resolved.cityName, districtName: resolved.districtName, countryID: countryID) {
                place.diyanetDistrictID = match.district.IlceID
                place.name = match.district.name
            }
            await finish(with: place)
        } catch {
            errorText = "Konum alınamadı. İl/ilçe seçerek devam edebilirsiniz."
        }
    }

    /// Bildirim izni yalnızca burada, kullanıcı bir konum seçip onboarding'i
    /// bitirirken istenir — her açılışta değil (iOS OnboardingView.finish() ile aynı desen).
    private func finish(with place: SavedLocation) async {
        settings.location = place
        settings.hasCompletedOnboarding = true
        _ = await notifications.requestAuthorization()
    }
}

private struct WatchCityPickerView: View {
    @ObservedObject var directory: DiyanetDirectory
    let onSelect: (SavedLocation) -> Void

    @EnvironmentObject private var location: LocationManager
    @State private var countries: [DiyanetCountry] = []
    @State private var selectedCountry: DiyanetCountry?
    @State private var pickingCountry = false
    @State private var cities: [DiyanetCity] = []
    @State private var selectedCity: DiyanetCity?
    @State private var districts: [DiyanetDistrict] = []
    @State private var errorText: String?
    @State private var isResolvingCoordinate = false

    var body: some View {
        List {
            if let selectedCity {
                Section(selectedCity.name) {
                    ForEach(districts) { district in
                        Button(district.name) {
                            Task { await select(city: selectedCity, district: district) }
                        }
                    }
                }
                .disabled(isResolvingCoordinate)
                Button("Geri") { self.selectedCity = nil; districts = [] }
            } else if pickingCountry {
                ForEach(countries) { country in
                    Button(country.name.capitalized(with: Locale(identifier: "tr_TR"))) {
                        selectedCountry = country
                        pickingCountry = false
                        Task { await loadCities(for: country) }
                    }
                }
            } else {
                if let selectedCountry {
                    Button("Ülke: \(selectedCountry.name.capitalized(with: Locale(identifier: "tr_TR")))") {
                        pickingCountry = true
                    }
                }
                ForEach(cities) { city in
                    Button(city.name) { Task { await select(city) } }
                }
            }
            if let errorText {
                Text(errorText).font(.caption2).foregroundStyle(.red)
            }
        }
        .task { await loadCities() }
    }

    private func loadCities() async {
        do {
            countries = try await directory.countries()
            selectedCountry = countries.first { $0.UlkeID == DiyanetDirectory.turkeyCountryID } ?? countries.first
            cities = try await directory.cities(countryID: selectedCountry?.UlkeID ?? DiyanetDirectory.turkeyCountryID)
        } catch { errorText = "Liste yüklenemedi." }
    }

    private func loadCities(for country: DiyanetCountry) async {
        cities = []
        do { cities = try await directory.cities(countryID: country.UlkeID) } catch { errorText = "Liste yüklenemedi." }
    }

    private func select(_ city: DiyanetCity) async {
        selectedCity = city
        do { districts = try await directory.districts(cityID: city.id) } catch { errorText = "İlçeler yüklenemedi." }
    }

    private func select(city: DiyanetCity, district: DiyanetDistrict) async {
        isResolvingCoordinate = true
        // Kıble + fallback için koordinat çöz (Diyanet vakti için gerekmez).
        // Çözülemezse koordinat nil kalır; placeholder saklanmaz.
        let coord = await location.geocodeCoordinate(
            district: district.name, city: city.name,
            countryName: selectedCountry?.name.capitalized(with: Locale(identifier: "tr_TR")))
        isResolvingCoordinate = false
        onSelect(SavedLocation(
            name: "\(district.name), \(city.name)",
            latitude: coord?.latitude,
            longitude: coord?.longitude,
            diyanetDistrictID: district.IlceID))
    }
}
