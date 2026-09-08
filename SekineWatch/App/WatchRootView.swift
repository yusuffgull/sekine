import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var iap: Store

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding || settings.location == nil {
                WatchOnboardingView()
            } else {
                premiumGatedContent
            }
        }
    }

    /// Dört durumun her biri ayrı ele alınır — ham `!iap.isPremium` kontrolü, cold-launch'ta
    /// (hâlâ `.loading` iken) veya geçici bir doğrulama belirsizliğinde (`.indeterminate`)
    /// ödeme yapmış bir kullanıcıya yanlışlıkla paywall göstermeye yol açardı.
    @ViewBuilder
    private var premiumGatedContent: some View {
        switch iap.entitlementState {
        case .loading:
            ProgressView()
        case .owned:
            WatchTabView()
        case .indeterminate:
            // `.indeterminate`, StoreKit'in ANLIK olarak dogrulayamadigi bir durumu ifade
            // eder — ASLA dogrudan paywall'a dusme, cunku odeme yapmis ama gecici olarak
            // dogrulanamayan bir kullaniciya tekrar satin alma sunmus oluruz. Üç alt durum:
            if iap.hadCachedOwnedEntitlementAtLaunch {
                // Cold-launch onbellegi `.owned` idi (Store'un mevcut mantiginda bu durumda
                // `.indeterminate`'e hic dusulmez, ama ileride degisirse bile burasi
                // savunmaci kalsin): iyimser sekilde normal (owned) akisi goster, arka
                // planda sessizce yeniden dogrula.
                WatchTabView()
                    .task { await iap.refreshEntitlements() }
            } else if iap.hadAnyCachedEntitlementAtLaunch {
                // Onbellekte kesin bir "sahip degil" bilgisi vardi; simdiki tarama sadece
                // gecici olarak dogrulayamadi. Son bilinen iyi cevap zaten notOwned oldugu
                // icin paywall gostermek yanlis kullaniciyi kilitlemiyor.
                WatchPaywallView()
                    .task { await iap.refreshEntitlements() }
            } else {
                // Ilk kurulum: hic onbellek bilgisi yok VE tarama simdilik belirsiz.
                // Ne owned ne paywall varsayma — kisa bir "kontrol ediliyor" bekleme
                // ekrani goster, arka planda yeniden dene.
                ProgressView()
                    .task { await iap.refreshEntitlements() }
            }
        case .notOwned:
            WatchPaywallView()
        }
    }
}

private struct WatchTabView: View {
    @State private var selection = "home"

    var body: some View {
        TabView(selection: $selection) {
            WatchHomeView()
                .tabItem { Label("Bugün", systemImage: "sun.max") }
                .tag("home")
            WatchQiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }
                .tag("qibla")
            WatchTesbihView()
                .tabItem { Label("Zikir", systemImage: "circle.grid.cross") }
                .tag("spiritual")
        }
        .tabViewStyle(.page)
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-uiTestTab"), i + 1 < args.count {
                selection = args[i + 1]
            }
        }
        #endif
    }
}
