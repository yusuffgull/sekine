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
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isResolving = false
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<ResolvedPlace, Error>?

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
    func resolveCurrentLocation() async throws -> ResolvedPlace {
        isResolving = true
        defer { isResolving = false }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    /// Metinle ilçe/şehir arar (offline değil; kullanıcı tetikler).
    func search(_ query: String) async -> [SavedLocation] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
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
        guard let loc = locations.first else { return }
        Task { @MainActor in
            let coord = loc.coordinate
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                let mark = placemarks.first
                let name = mark.map(Self.displayName) ?? "Konumum"
                let result = ResolvedPlace(
                    location: SavedLocation(name: name, latitude: coord.latitude, longitude: coord.longitude),
                    cityName: mark?.administrativeArea,
                    districtName: mark?.subAdministrativeArea ?? mark?.locality)
                continuation?.resume(returning: result)
            } catch {
                let result = ResolvedPlace(
                    location: SavedLocation(name: "Konumum", latitude: coord.latitude, longitude: coord.longitude),
                    cityName: nil, districtName: nil)
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
