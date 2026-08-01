import Foundation
import CoreLocation

/// Konum izni + GPS + ilçe adı çözümleme ve manuel arama.
/// Konum yalnızca cihazda vakit hesabı için kullanılır; hiçbir sunucuya
/// gönderilmez (Aladhan çağrısı hariç, o da yalnızca koordinat + tracking yok).
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isResolving = false
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<SavedLocation, Error>?

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Mevcut konumu alıp ilçe adına çözer.
    func resolveCurrentLocation() async throws -> SavedLocation {
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
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                let name = placemarks.first.map(Self.displayName) ?? "Konumum"
                let result = SavedLocation(
                    name: name,
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude)
                continuation?.resume(returning: result)
            } catch {
                let result = SavedLocation(
                    name: "Konumum",
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude)
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
