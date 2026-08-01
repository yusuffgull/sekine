import Foundation
import CoreLocation

/// Kıble yönü: bulunduğun konumdan Kâbe'ye great-circle açısı + pusula yönü.
@MainActor
final class QiblaManager: NSObject, ObservableObject {
    @Published var heading: Double = 0        // cihazın baktığı yön (derece)
    @Published var qiblaBearing: Double = 0   // kuzeyden Kâbe'ye açı (derece)
    @Published var headingAvailable = false

    private let manager = CLLocationManager()

    // Kâbe koordinatları
    private static let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    override init() {
        super.init()
        manager.delegate = self
        headingAvailable = CLLocationManager.headingAvailable()
    }

    func start(from location: SavedLocation?) {
        if let location {
            qiblaBearing = Self.bearing(
                from: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                to: Self.kaaba)
        }
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    /// İki koordinat arası başlangıç açısı (initial bearing), 0–360.
    nonisolated static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let Δλ = (to.longitude - from.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(y, x)
        return (θ * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}

extension QiblaManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.heading = value
            self.headingAvailable = true
        }
    }
}
