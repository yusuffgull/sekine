import Foundation

/// App ile Widget extension arasında paylaşılan sabitler.
enum AppGroup {
    static let identifier = "group.com.sekineapp.sekine"

    /// Paylaşılan veri konteyneri. Provisioning yoksa (ör. imzasız simülatör
    /// build'i) nil dönebilir; bu durumda çağıran taraf yerel fallback kullanır.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static let scheduleFileName = "schedule.json"
}
