import Foundation
import CoreLocation

/// Konum izni + GPS + ilçe adı çözümleme ve manuel arama.
/// Konum yalnızca cihazda vakit hesabı için kullanılır; hiçbir sunucuya
/// gönderilmez (Aladhan çağrısı hariç, o da yalnızca koordinat + tracking yok).
/// GPS çözümlemesinin sonucu: koordinat + Diyanet eşleştirmesi için il/ilçe adı.
struct ResolvedPlace {
    var location: SavedLocation
    var cityName: String?      // il (administrativeArea)
    var districtName: String?  // ilçe (subAdministrativeArea/locality)
    var isoCountryCode: String? // ör. "DE" — Diyanet ülke eşleştirmesi için (bkz. DiyanetDirectory.country(forISOCode:))
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isResolving = false
    @Published var lastError: String?

    private let manager = CLLocationManager()
    // GPS reverse-geocode ve kullanıcı metin araması ayrı CLGeocoder örnekleri kullanır:
    // aynı CLGeocoder aynı anda tek istek destekler, ikinci istek birinciyi
    // `CLError.geocodeCanceled` (kod 10) ile iptal eder — iki akış birbirine karışmasın diye.
    private let geocoder = CLGeocoder()
    private let searchGeocoder = CLGeocoder()
    private var continuation: CheckedContinuation<ResolvedPlace, Error>?
    private var inFlightLocationTask: Task<ResolvedPlace, Error>?

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Mevcut konumu alıp il/ilçe adına çözer.
    ///
    /// **Single-flight:** Aktif bir çözümleme sürerken yeni çağrı gelirse (ör. arka
    /// planda `SekineApp.bootstrap` sürerken kullanıcı Ayarlar'dan "Konumumu Kullan"a
    /// basarsa) yeni bir GPS isteği BAŞLATILMAZ — devam eden isteğin sonucu paylaşılır.
    /// Önceki tasarım tek bir `continuation`'ı her çağrıda ezip eskisini sonsuza dek
    /// asılı bırakıyordu (spinner hiç kapanmıyordu). Artık tüm çağıranlar aynı paylaşılan
    /// `Task`'ın `.value`'sini bekliyor: paylaşılan GPS isteği ve diğer bekleyenler tek bir
    /// çağıranın iptalinden etkilenmez. **Not:** bu "iptal edilen çağıran hemen
    /// `CancellationError` alır" anlamına GELMEZ — Swift concurrency'de iptal kooperatiftir;
    /// burada `await task.value`'yi bekleyen bir `Task` iptal edilse bile aktif bir
    /// `Task.checkCancellation()`/iptal kontrolü olmadığı sürece bu await noktası GPS isteği
    /// tamamlanana kadar askıda kalmaya devam eder ve sonucu (hatasız) döndürür. İptalin
    /// gerçek anlamda gözetildiği tek yer, iptal edilen `Task`'ın kendi `isCancelled`/
    /// `checkCancellation()` kontrolüdür — burada böyle bir kontrol yoktur.
    func resolveCurrentLocation() async throws -> ResolvedPlace {
        if let inFlightLocationTask {
            return try await inFlightLocationTask.value
        }
        isResolving = true
        let task = Task<ResolvedPlace, Error> { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            defer {
                self.isResolving = false
                self.inFlightLocationTask = nil
            }
            return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ResolvedPlace, Error>) in
                self.continuation = cont
                self.manager.requestLocation()
            }
        }
        inFlightLocationTask = task
        return try await task.value
    }

    /// GPS'ten okuyup Diyanet il/ilçe listesiyle eşleştirir (birebir vakit için).
    /// Önce GPS'in verdiği ülkeyi Diyanet'in ülke listesiyle eşleştirir (bulunamazsa
    /// Türkiye'ye düşer — eski davranışla geriye dönük uyumlu), SONRA o ülke içinde
    /// il/ilçe arar. Böylece yurt dışındaki bir kullanıcı sessizce Türkiye il listesinde
    /// aranıp "eşleşme yok" sonucuna düşmez. Eşleşme yine de yoksa koordinatla döner
    /// (yaklaşık vakit, `LocalCalculationProvider`), `matched: false`.
    func resolveAndMatchDiyanetLocation(directory: DiyanetDirectory) async throws
        -> (location: SavedLocation, matched: Bool) {
        let resolved = try await resolveCurrentLocation()
        let countryID = await directory.country(forISOCode: resolved.isoCountryCode)?.UlkeID
            ?? DiyanetDirectory.turkeyCountryID
        if let match = await directory.match(
            cityName: resolved.cityName, districtName: resolved.districtName, countryID: countryID
        ) {
            let locale = Locale(identifier: "tr_TR")
            let name = "\(match.district.name.capitalized(with: locale)), \(match.city.name.capitalized(with: locale))"
            return (SavedLocation(name: name, latitude: resolved.location.latitude,
                                   longitude: resolved.location.longitude,
                                   diyanetDistrictID: match.district.IlceID), true)
        }
        return (resolved.location, false)
    }

    /// İlçe/il adından koordinat çözer: önce ilçe, olmazsa il ile dener.
    /// Hiçbiri çözülemezse **nil** döner — uydurma bir koordinat ASLA üretilmez.
    /// (Kıble bu koordinattan hesaplandığı için yanlış değer kullanıcıyı sessizce
    /// yanlış yöne yönlendirir; koordinatsız kalmak yanlış olmaktan iyidir.)
    /// `countryName` verilmezse Türkiye varsayılır (eski çağıranlarla geriye dönük uyumlu).
    func geocodeCoordinate(district: String, city: String, countryName: String? = nil) async -> (latitude: Double, longitude: Double)? {
        let country = countryName ?? "Türkiye"
        for query in ["\(district), \(city), \(country)", "\(city), \(country)"] {
            if let hit = await search(query).first,
               let latitude = hit.latitude, let longitude = hit.longitude {
                return (latitude, longitude)
            }
        }
        return nil
    }

    /// Metinle ilçe/şehir arar (offline değil; kullanıcı tetikler).
    func search(_ query: String) async -> [SavedLocation] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        do {
            let placemarks = try await searchGeocoder.geocodeAddressString(query)
            return placemarks.compactMap { mark in
                guard let loc = mark.location else { return nil }
                return SavedLocation(
                    name: Self.displayName(for: mark),
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude)
            }
        } catch {
            return []
        }
    }

    private static func displayName(for mark: CLPlacemark) -> String {
        let parts = [mark.subAdministrativeArea ?? mark.locality,
                     mark.administrativeArea].compactMap { $0 }
        let unique = parts.reduce(into: [String]()) { acc, p in
            if !acc.contains(p) { acc.append(p) }
        }
        return unique.isEmpty ? (mark.name ?? "Bilinmeyen konum") : unique.joined(separator: ", ")
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationStatus = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            let coord = loc.coordinate
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                let mark = placemarks.first
                let name = mark.map(Self.displayName) ?? "Konumum"
                let result = ResolvedPlace(
                    location: SavedLocation(name: name, latitude: coord.latitude, longitude: coord.longitude),
                    cityName: mark?.administrativeArea,
                    districtName: mark?.subAdministrativeArea ?? mark?.locality,
                    isoCountryCode: mark?.isoCountryCode)
                continuation?.resume(returning: result)
            } catch {
                let result = ResolvedPlace(
                    location: SavedLocation(name: "Konumum", latitude: coord.latitude, longitude: coord.longitude),
                    cityName: nil, districtName: nil, isoCountryCode: nil)
                continuation?.resume(returning: result)
            }
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
