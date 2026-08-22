import SwiftUI
import StoreKit

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding, settings.location != nil {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        // Yazı boyutu ayarı tüm ekranları (varsayılan fontlar dahil) etkiler.
        .dynamicTypeSize(settings.fontScale.dynamicTypeSize)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore
    @State private var selection: String = MainTabView.initialTab
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }.tag("home")
            MonthlyView()
                .tabItem { Label("Aylık", systemImage: "calendar") }.tag("monthly")
            QiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }.tag("qibla")
            SpiritualView()
                .tabItem { Label("Zikir", systemImage: "circle.grid.cross") }.tag("spiritual")
            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }.tag("settings")
        }
        .task { await maybeAskForReview() }
        .alert(
            "Konum değişti mi?",
            isPresented: Binding(
                get: { settings.pendingLocationSuggestion != nil },
                set: { if !$0 { settings.pendingLocationSuggestion = nil } }
            ),
            presenting: settings.pendingLocationSuggestion
        ) { suggestion in
            Button("Güncelle") {
                settings.location = suggestion
                Task { await store.refresh(location: suggestion, settings: settings) }
            }
            Button("Hayır", role: .cancel) {
                // Aynı ilçe için bir daha sorulmasın (bkz. AppSettings.declinedLocationDistrictID).
                settings.declinedLocationDistrictID = suggestion.diyanetDistrictID
                settings.pendingLocationSuggestion = nil
            }
        } message: { suggestion in
            Text("Şu an \(suggestion.name) konumunda görünüyorsunuz. Namaz vakitlerini buna göre güncelleyelim mi?")
        }
    }

    /// Birkaç günlük düzenli kullanımdan sonra, sürüm başına en fazla bir kez sorar
    /// (sistem zaten yılda birkaç kezle sınırlar) — App Store rating sayısını artırmak
    /// organik arama sıralamasında önemli bir sinyal.
    private func maybeAskForReview() async {
        let defaults = UserDefaults.standard
        let countKey = "growth.significantOpenCount"
        let askedVersionKey = "growth.reviewAskedVersion"

        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard count >= 5, defaults.string(forKey: askedVersionKey) != currentVersion else { return }

        // Açılış ve konum sürüklenme kontrolü (SekineApp.bootstrap) otursun: ikisi aynı
        // anda modal açarsa rating diyalogu konum uyarısını yutuyor.
        try? await Task.sleep(for: .seconds(4))
        guard settings.pendingLocationSuggestion == nil else { return }

        // Sürüm kapısı yalnızca gerçekten sorduğumuzda yazılır; atladıysak sonraki
        // açılışta tekrar denenebilsin.
        defaults.set(currentVersion, forKey: askedVersionKey)
        requestReview()
    }

    /// DEBUG'da ekran görüntüsü otomasyonu için başlangıç sekmesi seçilebilir.
    static var initialTab: String {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-uiTestTab"), i + 1 < args.count {
            return args[i + 1]
        }
        #endif
        return "home"
    }
}
