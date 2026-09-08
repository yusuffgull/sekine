import Foundation
import StoreKit
#if os(iOS)
import UIKit
#endif

/// Uygulamanın Premium/bağış entitlement durumu.
///
/// `.loading`: henüz gerçek StoreKit doğrulaması tamamlanmadı (yalnızca cold-launch'ta,
/// App Group'ta önceden yazılmış bir değer de yoksa görülür).
/// `.owned` / `.notOwned`: gerçek (veya son bilinen önbelleğe alınmış) sonuç.
/// `.indeterminate`: en az bir doğrulanamayan (`.unverified`) ömürlük transaction
/// görüldü ama hiçbir GERÇEK doğrulanmış ömürlük transaction yok — bu durumda mevcut
/// `.owned` durumu ASLA `false`'a çevrilmez (bkz. `Store.refreshEntitlements()`).
enum EntitlementState: Equatable {
    case loading
    case owned
    case notOwned
    case indeterminate
}

/// `restore()` çağrısının kullanıcıya gösterilecek sonucu. `PaywallView` ve
/// `WatchPaywallView` aynı sözleşmeyi paylaşır.
enum RestoreOutcome: Equatable {
    case restored
    /// Restore çağrısı öncesinde entitlement zaten `.owned` idi ve tarama sonrası da
    /// `.owned` kaldı — yani bu çağrıda GERÇEKTEN yeni bir şey doğrulanmadı, sadece
    /// mevcut durum korundu (bkz. `Store.restore()`). `.restored`'dan kasıtlı olarak
    /// ayrı: çağıran taraf (ör. analytics/telemetri) "yeni bir restore oldu" ile
    /// "zaten sahipti" arasındaki farkı bilmek isteyebilir.
    case alreadyOwned
    case noPurchasesFound
    case cancelled
    case networkError
    case verificationFailed
    case indeterminate
    case other(String)

    /// Kullanıcıya gösterilecek metin. `nil` ise mesaj gösterilmez (başarı ya da sessiz iptal).
    var userFacingMessage: String? {
        switch self {
        case .restored, .cancelled:
            return nil
        case .alreadyOwned:
            return "Zaten Premium'a sahipsiniz."
        case .noPurchasesFound:
            return "Geri yüklenecek bir satın alma bulunamadı."
        case .networkError:
            return "Geri yükleme başarısız. İnternet bağlantınızı kontrol edin."
        case .verificationFailed:
            return "Satın alma doğrulanamadı. Lütfen daha sonra tekrar deneyin."
        case .indeterminate:
            return "Satın alma doğrulanıyor, lütfen birazdan tekrar deneyin."
        case .other:
            return "Geri yükleme başarısız oldu."
        }
    }
}

/// Bir `Transaction`'ın entitlement kararı için gereken minimal, StoreKit'ten BAĞIMSIZ
/// özeti. Gerçek `Transaction` StoreKit dışında üretilemediği (public initializer yok)
/// için, `applyVerifiedTransactionInfo(_:)` bu tipi alarak entitlement mantığını
/// StoreKit'ten tamamen ayırır — `StoreEntitlementTests` gerçek bir satın alma/restore
/// akışı (ki bu ortamda `SKTestSession` üzerinden `purchase()`/`AppStore.sync()`
/// çalıştırmak güvenilir değil) tetiklemeden bu tipi doğrudan inşa edip test edebilir.
struct VerifiedTransactionInfo: Equatable {
    let productID: String
    let isRevoked: Bool
}

/// StoreKit 2 mağaza sarmalayıcısı — backend YOK, cihaz-içi entitlement.
/// Ömürlük "Premium" (non-consumable) + bağış (consumable) ürünlerini yönetir.
///
/// Entitlement önbelleği: App Group UserDefaults'taki `cacheKey`, yalnızca en son
/// GERÇEK doğrulanmış sonucun türetilmiş bir kopyasıdır (widget/arka plan görevleri
/// StoreKit'e erişemediği için okur) — tek doğruluk kaynağı değildir, her app-launch'ta
/// StoreKit karşısında yeniden doğrulanır.
@MainActor
final class Store: ObservableObject, PremiumProviding {
    static let lifetimeID = "com.sekineapp.sekine.premium.lifetime"
    static let tipIDs = [
        "com.sekineapp.sekine.tip.small",
        "com.sekineapp.sekine.tip.medium",
        "com.sekineapp.sekine.tip.large"
    ]

    private static let cacheKey = "settings.isPremium"

    @Published private(set) var premiumProduct: Product?
    @Published private(set) var tipProducts: [Product] = []
    @Published private(set) var entitlementState: EntitlementState
    /// Cold-launch anında App Group önbelleğinde HERHANGİ bir değer (true ya da false)
    /// bulunup bulunmadığı — `entitlementState == .indeterminate` iken çağıranın (bkz.
    /// `WatchRootView`) "hiç bilgi yok, ilk kurulum" ile "önceden bir değer biliniyordu"
    /// durumlarını ayırt etmesi için. `entitlementState`'in aksine sonraki taramalarla
    /// GÜNCELLENMEZ — yalnızca cold-launch anındaki ham önbelleği yansıtan sabit bir
    /// anlık görüntüdür.
    let hadAnyCachedEntitlementAtLaunch: Bool
    /// Cold-launch anında App Group önbelleğinin `true` (owned) olup olmadığı. `true` ise
    /// `entitlementState` zaten `.owned` ile başlar VE unverified bir tarama onu ASLA
    /// `.indeterminate`'e düşüremez (bkz. `applyRefreshResult`) — yani bu bayrak pratikte
    /// `entitlementState == .indeterminate` iken hep `false` olur; yine de ileride
    /// davranış değişse bile çağıran taraf savunmacı şekilde kontrol edebilsin diye tutulur.
    let hadCachedOwnedEntitlementAtLaunch: Bool
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRestoring = false
    @Published var purchaseError: String?

    /// `isPremium`, geriye dönük uyumluluk için tutulan türetilmiş `Bool`. Yeni kod
    /// `entitlementState`'i (4 durumlu) kullanmalı — özellikle loading/indeterminate
    /// ayrımı gereken UI (bkz. `WatchRootView`).
    var isPremium: Bool { entitlementState == .owned }

    private var updatesTask: Task<Void, Never>?
    /// SADECE `refreshEntitlements()`'ın kendi taramasının sonucunu yazıp yazmayacağına
    /// karar vermek için kullanılır. `purchase()`/`Transaction.updates`, doğrulanmış bir
    /// event geldiği an — bu sayaca HİÇ bakmadan — state'i hemen yazar ve ardından bu
    /// sayacı artırarak o an sürmekte olan (ve artık bayatlamış olan) taramaları geçersiz
    /// kılar. Böylece ne "yavaş biten eski bir refresh yeni bir satın almayı ezer" ne de
    /// "bir refresh başladığı için doğrulanmış bir satın alma atılır" mümkün olur.
    /// AYRICA `refreshEntitlements()`'ın KENDİSİ de her çağrıldığında bu sayacı artırır
    /// (yalnızca okumaz) — böylece iki eş zamanlı `refreshEntitlements()` çağrısı (ör.
    /// cold-launch taraması ile bir `restore()` sonrası taraması çakışırsa) FARKLI
    /// generation'lar alır; hangisi daha geç biterse bitsin, daha düşük/eski generation'a
    /// sahip olan kendi sonucunu asla yazamaz (bkz. `applyRefreshResult`).
    /// `internal` (default) yerine `private` DEĞİL — `StoreEntitlementTests` bu sayacı
    /// ve aşağıdaki birkaç yardımcıyı `@testable import` ile doğrudan çağırarak generation
    /// güvencesini (stale-refresh atılır, verified event ASLA atılmaz) gerçek race'i
    /// tetiklemeye gerek kalmadan deterministik test eder.
    private(set) var refreshGeneration = 0
    private var restoreTask: Task<RestoreOutcome, Never>?
    /// Sadece test görünürlüğü için: `restore()` gerçekten yeni bir `Task` (dolayısıyla
    /// yeni bir `AppStore.sync()`) başlattığında artar — coalescing'in tek in-flight task'a
    /// indiğini test etmek için.
    private(set) var restoreTaskCreationCount = 0
    /// `restore()`'un gerçek `AppStore.sync()` çağrısı yerine kullandığı seam. Varsayılan
    /// gerçek StoreKit senkronizasyonudur; `StoreEntitlementTests` bunu (`@testable import`
    /// ile) sahte, anında dönen bir kapanışla değiştirerek restore-coalescing mantığını
    /// gerçek ağ/StoreKit gecikmesine veya bu ortamda güvenilir çalışmayan `SKTestSession`
    /// satın alma akışına bağımlı olmadan deterministik test eder.
    var syncProvider: () async throws -> Void = { try await AppStore.sync() }
    /// `refreshEntitlements()`'ın `Transaction.currentEntitlements` taraması yerine
    /// kullandığı seam — bu ortamda (`CODE_SIGNING_ALLOWED=NO`) StoreKit Testing daemon'ı
    /// çalışmadığından bu AsyncSequence de `purchase()`/`AppStore.sync()` gibi süresiz
    /// askıda kalabiliyor. `StoreEntitlementTests` bunu anında dönen sahte bir sonuçla
    /// değiştirerek `restore()`/`refreshEntitlements()`'ı deterministik test eder.
    var entitlementsScanProvider: () async -> (foundOwnedLifetime: Bool, sawUnverifiedLifetime: Bool) = {
        var foundOwnedLifetime = false
        var sawUnverifiedLifetime = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Store.lifetimeID {
                    foundOwnedLifetime = true
                }
            case .unverified(let transaction, let error):
                if transaction.productID == Store.lifetimeID {
                    sawUnverifiedLifetime = true
                    print("Store: doğrulanamayan ömürlük transaction görüldü: \(error)")
                }
            }
        }
        return (foundOwnedLifetime, sawUnverifiedLifetime)
    }

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestForcePremium") {
            entitlementState = .owned
            hadAnyCachedEntitlementAtLaunch = true
            hadCachedOwnedEntitlementAtLaunch = true
            return
        }
        #endif
        // Cold-launch: gerçek doğrulama bitene kadar App Group'taki son bilinen değeri
        // göster (varsa) — "loading sırasında paywall gösterme" sorununu çözer.
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        if let cached = defaults.object(forKey: Self.cacheKey) as? Bool {
            entitlementState = cached ? .owned : .notOwned
            hadAnyCachedEntitlementAtLaunch = true
            hadCachedOwnedEntitlementAtLaunch = cached
        } else {
            entitlementState = .loading
            hadAnyCachedEntitlementAtLaunch = false
            hadCachedOwnedEntitlementAtLaunch = false
        }

        // Uygulama açıkken gelen (başka cihaz/aile paylaşımı/iade) işlemleri dinle.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                await self.handleTransactionUpdate(update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [Self.lifetimeID] + Self.tipIDs)
            premiumProduct = products.first { $0.id == Self.lifetimeID }
            // Bağış ürünlerini fiyata göre sırala.
            tipProducts = products
                .filter { Self.tipIDs.contains($0.id) }
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Ürünler yüklenemedi. İnternet bağlantınızı kontrol edin."
        }
    }

    /// `isPremium` + App Group önbelleğini TEK yerde, atomik olarak yazar.
    private func setPremium(_ owned: Bool) {
        entitlementState = owned ? .owned : .notOwned
        (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
            .set(owned, forKey: Self.cacheKey)
    }

    /// `purchase()` ve `Transaction.updates` tarafından paylaşılan tek işleyici.
    /// Doğrulanmış bir transaction geldiği an — generation'a HİÇ bakmadan — entitlement
    /// state'i senkron/atomik olarak yazar (arada `await` yok), SONRA `finish()` çağırır
    /// (Apple'ın önerdiği sıra: önce içerik/erişim teslimi, sonra finish). Bağış
    /// (consumable) transaction'ları entitlement mantığına hiç girmez, sadece finish edilir.
    func handleVerifiedTransaction(_ transaction: Transaction) async {
        applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: transaction.productID, isRevoked: false)
        )
        await transaction.finish()
    }

    private func handleTransactionUpdate(_ update: VerificationResult<Transaction>) async {
        switch update {
        case .verified(let transaction):
            // Açık iade/iptal `revocationDate` ile burada, `Transaction.updates`'te
            // yakalanır — `currentEntitlements` taraması (refreshEntitlements) revoke
            // edilmiş transaction'ları zaten hiç görmez, orada tekrar kontrol anlamsız.
            applyVerifiedTransactionInfo(
                VerifiedTransactionInfo(
                    productID: transaction.productID,
                    isRevoked: transaction.revocationDate != nil
                )
            )
            await transaction.finish()
        case .unverified(_, let error):
            // Doğrulanamayan bir güncelleme entitlement'ı ASLA değiştirmez, sadece loglanır.
            print("Store: Transaction.updates doğrulanamadı: \(error)")
        }
    }

    /// `handleVerifiedTransaction`/`handleTransactionUpdate`'in StoreKit'ten bağımsız,
    /// senkron karar/yazma adımı — generation'a HİÇ bakmaz (verified bir event ASLA
    /// atılmaz), sadece kendi generation'ını artırarak o an sürmekte olan bayatlamış
    /// `refreshEntitlements()` taramalarını geçersiz kılar. `StoreEntitlementTests` bunu
    /// gerçek bir StoreKit satın alma/restore akışı tetiklemeden doğrudan çağırır.
    func applyVerifiedTransactionInfo(_ info: VerifiedTransactionInfo) {
        guard info.productID == Self.lifetimeID else { return }
        setPremium(!info.isRevoked)
        refreshGeneration += 1
    }

    /// Geçmiş satın almaları keşfetmek için StoreKit'in mevcut entitlement'larını
    /// tarar. Yalnızca app-launch'ta ve `restore()` sonrası çağrılır — satın alma/güncelleme
    /// akışları (`handleVerifiedTransaction`) entitlement'ı doğrudan uygular, yeniden
    /// taramaya gerek duymaz.
    ///
    /// KRİTİK: generation'ı burada yalnızca OKUMAK yetmez, ARTTIRMAK gerekir. Aksi halde
    /// iki eş zamanlı `refreshEntitlements()` çağrısı (ör. cold-launch'taki `init()`
    /// taraması ile bir `restore()` sonrası taraması çakışırsa) AYNI generation'ı okur;
    /// biri diğerinden daha güncel/doğru bir sonuçla dönse bile "generation eşleşiyor"
    /// diye ikisi de yazabilir ve daha geç biten (ama verisi daha bayat olabilecek) tarama
    /// diğerini ezer. Her çağrı kendi generation'ını almalı ki `applyRefreshResult`'taki
    /// `refreshGeneration == generation` kontrolü yalnızca "benden SONRA kimse (bir başka
    /// refresh ya da verified bir purchase/update) generation'ı ilerletmedi mi" sorusuna
    /// gerçekten cevap versin.
    func refreshEntitlements() async {
        refreshGeneration += 1
        let myGeneration = refreshGeneration
        let scan = await entitlementsScanProvider()
        applyRefreshResult(
            foundOwnedLifetime: scan.foundOwnedLifetime,
            sawUnverifiedLifetime: scan.sawUnverifiedLifetime,
            generation: myGeneration
        )
    }

    /// `refreshEntitlements()`'ın (potansiyel olarak uzun süren `await` içeren) taraması
    /// bittikten sonraki senkron karar/yazma adımı. Taramadan ayrıştırılmasının tek nedeni
    /// test edilebilirlik: `StoreEntitlementTests`, gerçek bir StoreKit race'i tetiklemeye
    /// çalışmak yerine bu fonksiyonu doğrudan, kontrollü generation değerleriyle çağırarak
    /// "stale bir taramanın sonucu asla verified bir purchase/update'i ezmez" garantisini
    /// deterministik olarak doğrular.
    func applyRefreshResult(foundOwnedLifetime: Bool, sawUnverifiedLifetime: Bool, generation: Int) {
        // Bu tarama sürerken bir purchase/update state'i çoktan (daha güncel bir bilgiyle)
        // yazdıysa, bu taramanın bayatlamış sonucu ASLA state'in üzerine yazılmaz.
        guard refreshGeneration == generation else { return }

        if foundOwnedLifetime {
            setPremium(true)
        } else if sawUnverifiedLifetime {
            // Hiçbir doğrulanmış ömürlük transaction yok ama doğrulanamayan bir tane var —
            // bu belirsizliği "sahip değil"e indirgemek, geçici bir doğrulama sorununda
            // ödeme yapmış kullanıcıyı kilitleyebilir. Zaten `.owned` ise ASLA dokunma
            // (unverified owned'ı false yapmaz); değilse belirsiz olarak işaretle.
            if entitlementState != .owned {
                entitlementState = .indeterminate
            }
        } else {
            setPremium(false)
        }
    }

    /// Satın alma. Başarılıysa true. (Bağışlar entitlement vermez; sadece finish edilir.)
    ///
    /// `confirmIn`: yalnızca test/anchor-belirsizliği durumları için — production çağrı
    /// yerleri (`PaywallView`, `WatchPaywallView`) bunu HİÇ vermez, `nil` kalır ve davranış
    /// önceki gibi StoreKit'in otomatik UI-anchor keşfini kullanır. `StoreEntitlementTests`,
    /// unit-test host'unda uygulamanın `UIWindowScene`'i `foregroundInactive` kaldığı için
    /// (StoreKit'in otomatik anchor keşfi bunu bulamayıp sonsuza kadar beklediği için) test
    /// tarafında elde ettiği sahne'yi burada açıkça geçer.
#if os(iOS)
    @discardableResult
    func purchase(_ product: Product, confirmIn windowScene: UIWindowScene? = nil) async -> Bool {
        purchaseError = nil
        do {
            let result: Product.PurchaseResult
            if let windowScene {
                result = try await product.purchase(confirmIn: windowScene)
            } else {
                result = try await product.purchase()
            }
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Satın alma doğrulanamadı."
                    return false
                }
                await handleVerifiedTransaction(transaction)
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Satın alma onay bekliyor."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Satın alma tamamlanamadı."
            return false
        }
    }
#else
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Satın alma doğrulanamadı."
                    return false
                }
                await handleVerifiedTransaction(transaction)
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Satın alma onay bekliyor."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Satın alma tamamlanamadı."
            return false
        }
    }
#endif

    /// Önceki satın almaları geri yükler (App Store hesabıyla senkron). Zaten çalışan
    /// bir restore varsa yeni bir `AppStore.sync()` tetiklemez, mevcut olanı bekler.
    ///
    /// Coalescing: `restoreTask`, task'ın KENDİSİ tarafından — tamamlandığı an, `return`'den
    /// ÖNCE — `nil`'e sıfırlanır (aşağıdaki task closure'ının sonuna bak). Bu iki şeyi
    /// garanti eder: (1) `[weak self]` zaten güçlü bir retain-cycle oluşturmuyordu, ama
    /// task'ın kendini temizlemesi olmadan `syncProvider()`/tarama hiç dönmezse
    /// `restoreTask` süresiz dolu kalır ve YENİ bir restore() çağrısı hep bu "asılı" task'ı
    /// bekler — kendi kendini temizleme bu riski azaltır (task bittiğinde iz bırakmaz); (2)
    /// dışarıdaki `restore()` fonksiyonu `await task.value`'dan SONRA `restoreTask`'e ASLA
    /// dokunmaz — dokunsaydı, bu fonksiyon uyanmadan önce ARAYA GİREN başka bir `restore()`
    /// çağrısı zaten yeni bir task başlatmış olabilir ve dışarıdaki eski kod o YENİ task'ı
    /// yanlışlıkla `nil`'lerdi. Böylece "tamamlanmış eski bir task'ın yeniden kullanılması"
    /// ve "yeni başlamış bir task'ın yanlışlıkla iptal edilmiş gibi silinmesi" riskleri ortadan
    /// kalkar.
    @discardableResult
    func restore() async -> RestoreOutcome {
        if let existing = restoreTask {
            return await existing.value
        }
        purchaseError = nil
        isRestoring = true
        restoreTaskCreationCount += 1
        let task = Task<RestoreOutcome, Never> { [weak self] () -> RestoreOutcome in
            let outcome: RestoreOutcome
            if let self {
                do {
                    try await self.syncProvider()
                    // Restore'un GERÇEKTEN yeni bir şey doğrulayıp doğrulamadığını
                    // ayırt edebilmek için tarama öncesi durumu yakala (bkz. `RestoreOutcome
                    // .alreadyOwned` dokümantasyonu).
                    let priorState = self.entitlementState
                    await self.refreshEntitlements()
                    switch self.entitlementState {
                    case .owned:
                        outcome = (priorState == .owned) ? .alreadyOwned : .restored
                    case .indeterminate:
                        outcome = .indeterminate
                    case .notOwned, .loading:
                        outcome = .noPurchasesFound
                    }
                } catch {
                    outcome = self.restoreOutcome(for: error)
                }
            } else {
                outcome = .other("Store serbest bırakıldı")
            }
            // Kendi kendini temizle — bkz. yukarıdaki fonksiyon dokümantasyonu. `self` hâlâ
            // canlıysa bu üç yazma, bu closure'ın döndüğü (ve dolayısıyla tüm `await
            // task.value` bekleyicilerinin uyandığı) andan KESİNLİKLE ÖNCE tamamlanır —
            // aralarında `await` olmadığı için MainActor'da kesintisiz çalışırlar.
            self?.restoreTask = nil
            self?.isRestoring = false
            self?.purchaseError = outcome.userFacingMessage
            return outcome
        }
        restoreTask = task
        return await task.value
    }

    func restoreOutcome(for error: Error) -> RestoreOutcome {
        if error is CancellationError {
            return .cancelled
        }
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return .networkError
            case .userCancelled:
                return .cancelled
            case .notEntitled:
                // Apple semantiği: `notEntitled` "bu uygulamanın bu entitlement'a erişimi
                // yok" demektir — bir DOĞRULAMA hatası değil (`.verificationFailed` yalnızca
                // gerçek `VerificationResult.unverified` durumuna ayrılmalı). Kullanıcı
                // açısından anlamı "geri yüklenecek bir satın alma yok"a en yakını.
                return .noPurchasesFound
            default:
                return .other(String(describing: storeKitError))
            }
        }
        if error is URLError {
            return .networkError
        }
        return .other(error.localizedDescription)
    }
}
