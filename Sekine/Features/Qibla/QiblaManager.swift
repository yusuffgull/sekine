import Foundation
import CoreLocation

/// Kıble yönü: bulunduğun konumdan Kâbe'ye great-circle açısı + pusula yönü.
@MainActor
final class QiblaManager: NSObject, ObservableObject {
    @Published var heading: Double = 0        // cihazın baktığı yön (derece)
    @Published var qiblaBearing: Double = 0   // kuzeyden Kâbe'ye açı (derece)
    @Published var headingAvailable = false
    /// Kıble açısı GERÇEKTEN hesaplanabildi mi. false iken UI açı/ok göstermemeli —
    /// aksi halde 0° (kuzey) kıble sanılır. Yanlış yön göstermek kabul edilemez.
    @Published var bearingAvailable = false
    /// Açı, kayıtlı konum yerine cihazın anlık GPS konumundan hesaplandı mı.
    @Published var usingLiveLocation = false

    private let manager = CLLocationManager()

    // Kâbe koordinatları
    private static let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        headingAvailable = CLLocationManager.headingAvailable()
    }

    /// Kıble açısını kurar. Konum izni varsa cihazın **gerçek** konumundan hesaplar
    /// (tek seferlik ölçüm; sürekli güncelleme yok). İzin yoksa yalnızca kayıtlı konumun
    /// DOĞRULANMIŞ koordinatına düşer. İkisi de yoksa açı gösterilmez.
    func start(from location: SavedLocation?) {
        if let coordinate = location?.coordinate {
            qiblaBearing = Self.bearing(from: coordinate, to: Self.kaaba)
            bearingAvailable = true
            usingLiveLocation = false
        } else {
            bearingAvailable = false
            usingLiveLocation = false
        }

        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }

        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
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

    /// Gerçek konum geldi → açıyı ondan hesapla (kayıtlı konumdan daha kesin).
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.qiblaBearing = Self.bearing(from: coordinate, to: Self.kaaba)
            self.bearingAvailable = true
            self.usingLiveLocation = true
        }
    }

    /// Konum alınamadı: kayıtlı koordinat varsa onunla devam edilir (start'ta kuruldu),
    /// yoksa açı gösterilmez — uydurma yön üretilmez.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.requestLocation()
    }
}
