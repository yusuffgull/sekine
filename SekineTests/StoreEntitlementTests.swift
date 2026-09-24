import XCTest
import StoreKit
@testable import Sekine

/// `Store` (StoreKit 2 sarmalayıcı) entitlement/restore güvenilirlik testleri.
///
/// Bu testler BİLİNÇLİ olarak gerçek bir `SKTestSession` satın alma/`AppStore.sync()`
/// akışı TETİKLEMEZ: bu sandbox/CI ortamında (`CODE_SIGNING_ALLOWED=NO`) hem
/// `product.purchase()` hem `AppStore.sync()` çağrıları süresiz askıda kalıyor
/// (`SKInternalErrorDomain Code=3`, "client is not entitled" — StoreKit Testing
/// daemon'ı imza/entitlement eksikliği yüzünden gerçek bir işlemi asla tamamlamıyor).
/// Açık bir `UIWindowScene` `confirmIn:` olarak geçmek (anchor-bulunamama teorisi)
/// denendi, aynı ortamda hâlâ süresiz askıda kaldığı doğrulandı — kök neden StoreKit
/// Testing daemon'ının bu build konfigürasyonunda hiç çalışmaması, bir UI-anchor sorunu
/// değil. Bu yüzden `Store`, entitlement kararını StoreKit'ten tamamen ayıran saf
/// seam'ler sunuyor (bkz. `Store.swift`):
/// - `applyVerifiedTransactionInfo(_:)` — doğrulanmış bir transaction'ın (satın alma
///   veya `Transaction.updates`) entitlement'a nasıl uygulandığını, gerçek bir
///   `Transaction` nesnesi üretmeye gerek kalmadan test eder.
/// - `applyRefreshResult(...)` — `refreshEntitlements()` taramasının generation-korumalı
///   yazma adımını test eder.
/// - `syncProvider` — `restore()`'un `AppStore.sync()` çağrısını enjekte edilebilir bir
///   kapanışla değiştirir, restore-coalescing'i gerçek ağ/StoreKit gecikmesine bağımlı
///   olmadan deterministik test eder.
///
/// Gerçek StoreKit entegrasyonu (Ask to Buy, cold-launch, canlı `SKTestSession` satın
/// alma) bu ortamda otomatikleştirilemiyor — `Sekine/Sekine.storekit` yalnızca gerçek
/// cihaz/imzalı simülatörde yapılacak manuel sandbox testi için saklanıyor.
@MainActor
final class StoreEntitlementTests: XCTestCase {

    private var store: Store!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // `Store.init()` cold-launch'ta App Group (yoksa `.standard`) UserDefaults'taki
        // "settings.isPremium" önbelleğini okur — bu, gerçek/kalıcı bir UserDefaults
        // olduğundan bir önceki test çalıştırmasından (`setPremium(true)` yazan bir test)
        // sızıp yeni bir `Store()`'u `.owned` olarak başlatabilir. Her testin `.loading`
        // durumundan başladığından emin olmak için önbelleği burada temizliyoruz.
        (UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
            .removeObject(forKey: "settings.isPremium")
        store = Store()
        // `Store.init()` arka planda bir `refreshEntitlements()` tetikler ve `restore()`
        // da her zaman `refreshEntitlements()` çağırır — ikisi de varsayılan olarak
        // `Transaction.currentEntitlements`'ı tarar. Bu ortamda (`CODE_SIGNING_ALLOWED=NO`)
        // StoreKit Testing daemon'ı çalışmadığından bu tarama da `purchase()`/
        // `AppStore.sync()` gibi süresiz askıda kalabiliyor — anında dönen sahte bir
        // sonuçla değiştirerek TÜM testleri bu hataya bağımlı olmaktan kurtarıyoruz.
        store.entitlementsScanProvider = { (foundOwnedEntitlement: false, sawUnverifiedEntitlement: false) }
    }

    override func tearDownWithError() throws {
        store = nil
        try super.tearDownWithError()
    }

    // MARK: - Verified transaction → entitlement

    /// En azından: verified bir transaction geldiği an entitlement HEMEN `.owned` olmalı
    /// (finish'ten ÖNCE yazılmış olması, sıranın doğru olduğunun kanıtı).
    func testVerifiedPurchaseAppliesEntitlementImmediately() {
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.lifetimeID, isRevoked: false)
        )
        XCTAssertEqual(store.entitlementState, .owned)
        XCTAssertTrue(store.isPremium)
    }

    /// Yıllık abonelik de ömürlük gibi entitlement vermeli — `entitlementProductIDs`
    /// ikisini de kapsar (bkz. `Store.entitlementProductIDs`).
    func testVerifiedYearlySubscriptionPurchaseAppliesEntitlement() {
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.yearlyID, isRevoked: false)
        )
        XCTAssertEqual(store.entitlementState, .owned)
        XCTAssertTrue(store.isPremium)
    }

    /// Bağış (consumable) ürünleri entitlement mantığına hiç girmemeli — `guard` bunları
    /// sessizce yok sayar, state'e dokunmaz.
    func testVerifiedTipPurchaseNeverGrantsEntitlement() {
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.tipIDs[0], isRevoked: false)
        )
        XCTAssertNotEqual(store.entitlementState, .owned)
    }

    /// KRİTİK: generation sayacı SADECE stale bir refresh taramasını atmalı — verified bir
    /// purchase/update event'ini ASLA atmamalı. Senaryo (VISION'ın 3. tur bulgusu):
    /// bir refresh taraması başlar (generation'ı yakalar) → tarama sürerken bir purchase
    /// tamamlanır ve `.owned` yazar (generation'ı artırır) → YAVAŞ süren eski taramanın
    /// sonucu (ör. "bulunamadı") geri döner ve state'in üzerine yazılmaya çalışır.
    func testStaleRefreshNeverOverwritesVerifiedPurchase() {
        // 1) "Refresh başladı" — generation'ı bu anda yakala.
        let staleGeneration = store.refreshGeneration

        // 2) Bu sırada gerçek bir satın alma tamamlanıyor (generation'a hiç bakmadan
        //    doğrudan yazıyor, sonra kendi generation'ını artırıyor).
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.lifetimeID, isRevoked: false)
        )
        XCTAssertEqual(store.entitlementState, .owned)
        XCTAssertGreaterThan(store.refreshGeneration, staleGeneration)

        // 3) Eski (yavaş biten) taramanın sonucu şimdi geliyor — "hiçbir şey bulamadım".
        //    Bu, gerçek `refreshEntitlements()`'ın stale generation ile
        //    `applyRefreshResult` çağırmasıyla birebir aynı kod yolu.
        store.applyRefreshResult(
            foundOwnedEntitlement: false,
            sawUnverifiedEntitlement: false,
            generation: staleGeneration
        )

        // Stale sonuç ATILMALI — verified purchase'ın yazdığı `.owned` KORUNMALI.
        XCTAssertEqual(store.entitlementState, .owned)
        XCTAssertTrue(store.isPremium)
    }

    /// Generation'ın asıl görevi: gerçekten GÜNCEL bir refresh taraması (araya başka bir
    /// purchase/update girmemiş) sonucunu normal şekilde yazabilmeli.
    func testFreshRefreshResultIsApplied() {
        let myGeneration = store.refreshGeneration
        store.applyRefreshResult(foundOwnedEntitlement: true, sawUnverifiedEntitlement: false, generation: myGeneration)
        XCTAssertEqual(store.entitlementState, .owned)
    }

    /// KRİTİK (VISION 5. tur bulgusu #1): generation sayacı yalnızca purchase/update'e karşı
    /// değil, İKİ refresh-vs-refresh arasında da korumalı olmalı. `refreshEntitlements()`
    /// KENDİ generation'ını (yalnızca OKUMAK değil) ARTIRMALI ki eş zamanlı başlayan iki
    /// refresh farklı generation'lara sahip olsun. Senaryo: önce başlayan bir refresh (eski/
    /// düşük generation) tarama sırasında askıda kalır; bu sırada sonra başlayan ikinci bir
    /// refresh (yeni/yüksek generation) hemen biter ve "owned" bulur; ardından İLK (bayat)
    /// refresh de döner ama "bulunamadı" der — bu bayat sonuç ASLA yazılmamalı.
    func testOlderConcurrentRefreshNeverOverwritesNewerRefreshResult() async {
        var callCount = 0
        var releaseFirstScan: CheckedContinuation<Void, Never>?

        store.entitlementsScanProvider = {
            callCount += 1
            if callCount == 1 {
                // İlk (önce başlayan) refresh: ikinci refresh sonucunu yazana kadar burada
                // askıda kalır, sonra bayat bir "bulunamadı" sonucu döner.
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    releaseFirstScan = continuation
                }
                return (foundOwnedEntitlement: false, sawUnverifiedEntitlement: false)
            } else {
                // İkinci (sonra başlayan, daha güncel) refresh: hemen "owned" bulur.
                return (foundOwnedEntitlement: true, sawUnverifiedEntitlement: false)
            }
        }

        async let first: Void = store.refreshEntitlements()
        // İlk refresh'in generation'ını alıp scanProvider içinde askıya girmesini garanti et.
        while callCount < 1 { await Task.yield() }

        async let second: Void = store.refreshEntitlements()
        // İkinci refresh kendi generation'ını alıp taramasını tamamlayıp state'i "owned"
        // yazana kadar bekle.
        while store.entitlementState != .owned { await Task.yield() }

        // Artık daha güncel (2.) refresh sonucunu yazdı — bayat (1.) refresh'i serbest bırak.
        releaseFirstScan?.resume()
        _ = await (first, second)

        XCTAssertEqual(
            store.entitlementState, .owned,
            "önce başlayan (bayat/düşük generation) refresh'in geç gelen sonucu, sonra başlayan (yeni/yüksek generation) refresh'in sonucunu EZMEMELİ"
        )
    }

    /// Unverified bir sonuç, zaten `.owned` olan bir durumu ASLA `false`/indeterminate'e
    /// çeviremez (mission bulgusu: "ödeme yapan kullanıcı premium'u kaybedebilir").
    func testUnverifiedNeverDowngradesOwned() {
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.lifetimeID, isRevoked: false)
        )
        XCTAssertEqual(store.entitlementState, .owned)

        let myGeneration = store.refreshGeneration
        store.applyRefreshResult(foundOwnedEntitlement: false, sawUnverifiedEntitlement: true, generation: myGeneration)

        XCTAssertEqual(store.entitlementState, .owned, "unverified, zaten owned olan durumu ASLA ezmemeli")
    }

    /// Hiç satın alma yokken bir unverified sonuç görülürse, sert bir `notOwned` yerine
    /// `indeterminate` yazılmalı (ödeme yapmış ama geçici olarak doğrulanamayan bir
    /// kullanıcıyı yanlışlıkla kilitlememek için).
    func testUnverifiedWithoutOwnershipBecomesIndeterminate() {
        XCTAssertNotEqual(store.entitlementState, .owned)
        let myGeneration = store.refreshGeneration
        store.applyRefreshResult(foundOwnedEntitlement: false, sawUnverifiedEntitlement: true, generation: myGeneration)
        XCTAssertEqual(store.entitlementState, .indeterminate)
    }

    /// Hiçbir transaction (ne verified ne unverified) yoksa `notOwned` yazılmalı.
    func testNoEntitlementsBecomesNotOwned() {
        let myGeneration = store.refreshGeneration
        store.applyRefreshResult(foundOwnedEntitlement: false, sawUnverifiedEntitlement: false, generation: myGeneration)
        XCTAssertEqual(store.entitlementState, .notOwned)
        XCTAssertFalse(store.isPremium)
    }

    /// Açık revocation (iade/iptal) `applyVerifiedTransactionInfo` üzerinden geldiğinde
    /// entitlement kesin olarak `notOwned`'a döner.
    func testRevokedTransactionClearsOwnership() {
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.lifetimeID, isRevoked: false)
        )
        XCTAssertEqual(store.entitlementState, .owned)

        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.lifetimeID, isRevoked: true)
        )
        XCTAssertEqual(store.entitlementState, .notOwned)
    }

    // MARK: - Restore coalescing

    /// Restore coalescing: art arda (ilki bitmeden) tetiklenen iki `restore()` çağrısı
    /// tek bir in-flight `Task` (dolayısıyla tek bir senkronizasyon) paylaşmalı — ikinci
    /// çağrı yeni bir tarama BAŞLATMAMALI, birincisinin sonucunu beklemeli.
    func testConcurrentRestoreCallsCoalesceToSingleTask() async {
        XCTAssertEqual(store.restoreTaskCreationCount, 0)
        store.syncProvider = { await Task.yield() }

        async let first = store.restore()
        async let second = store.restore()
        let (firstOutcome, secondOutcome) = await (first, second)

        XCTAssertEqual(firstOutcome, secondOutcome)
        XCTAssertEqual(store.restoreTaskCreationCount, 1, "iki eşzamanlı restore() çağrısı TEK task oluşturmalı")
        XCTAssertFalse(store.isRestoring)
    }

    /// Restore tamamlandıktan sonra yeni bir `restore()` çağrısı YENİ bir task başlatmalı
    /// (coalescing yalnızca gerçekten çakışan çağrılar için, kalıcı bir kilitlenme değil).
    func testRestoreAfterCompletionStartsNewTask() async {
        store.syncProvider = { await Task.yield() }

        _ = await store.restore()
        XCTAssertEqual(store.restoreTaskCreationCount, 1)
        _ = await store.restore()
        XCTAssertEqual(store.restoreTaskCreationCount, 2)
    }

    /// `syncProvider` hata fırlatırsa `restore()` bu hatayı `restoreOutcome(for:)` ile
    /// kategorize edip döndürmeli, sessizce yutmamalı.
    func testRestoreSurfacesSyncProviderError() async {
        store.syncProvider = { throw URLError(.notConnectedToInternet) }
        let outcome = await store.restore()
        XCTAssertEqual(outcome, .networkError)
        XCTAssertFalse(store.isRestoring)
    }

    /// KRİTİK (VISION 5. tur bulgusu #4a): store zaten `.owned` iken bir `restore()`
    /// çağrısı tarama sonunda SADECE unverified bir transaction görürse (state korunur,
    /// hâlâ `.owned`) — bu restore çağrısında GERÇEKTE yeni bir şey doğrulanmadı, sadece
    /// eski durum korundu. `.restored` YANLIŞ bir izlenim verir ("az önce bir şey geri
    /// yüklendi" gibi); doğrusu `.alreadyOwned`.
    func testRestoreOfAlreadyOwnedStoreWithOnlyUnverifiedScanReportsAlreadyOwnedNotRestored() async {
        store.applyVerifiedTransactionInfo(
            VerifiedTransactionInfo(productID: Store.lifetimeID, isRevoked: false)
        )
        XCTAssertEqual(store.entitlementState, .owned)

        store.syncProvider = {}
        store.entitlementsScanProvider = { (foundOwnedEntitlement: false, sawUnverifiedEntitlement: true) }

        let outcome = await store.restore()

        XCTAssertEqual(store.entitlementState, .owned, "zaten owned olan durum korunmalı")
        XCTAssertNotEqual(outcome, .restored, "bu restore çağrısında YENİ hiçbir şey doğrulanmadı")
        XCTAssertEqual(outcome, .alreadyOwned)
    }

    /// Karşıt durum: store `.owned` DEĞİLKEN restore taraması gerçekten bir verified
    /// ömürlük transaction bulursa, bu GERÇEK bir restore'dur ve `.restored` dönmelidir.
    func testRestoreOfNotOwnedStoreWithVerifiedScanReportsRestored() async {
        XCTAssertNotEqual(store.entitlementState, .owned)
        store.syncProvider = {}
        store.entitlementsScanProvider = { (foundOwnedEntitlement: true, sawUnverifiedEntitlement: false) }

        let outcome = await store.restore()

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(store.entitlementState, .owned)
    }

    // MARK: - RestoreOutcome hata kategorileştirme (StoreKit'ten bağımsız, saf mapping)

    func testRestoreOutcomeMapsNetworkErrorToNetworkError() {
        let outcome = store.restoreOutcome(for: URLError(.notConnectedToInternet))
        XCTAssertEqual(outcome, .networkError)
    }

    func testRestoreOutcomeMapsUserCancelledToCancelled() {
        let outcome = store.restoreOutcome(for: StoreKitError.userCancelled)
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertNil(outcome.userFacingMessage, "iptal sessiz kalmalı")
    }

    /// KRİTİK (VISION 5. tur bulgusu #4b): Apple semantiğinde `notEntitled`, "uygulamanın
    /// bu entitlement'a erişimi yok" demektir — bir DOĞRULAMA hatası değildir.
    /// `.verificationFailed` yalnızca gerçek `VerificationResult.unverified` durumuna
    /// (bkz. `entitlementsScanProvider`'daki `.unverified` kolu) ayrılmalı.
    func testRestoreOutcomeMapsNotEntitledToNoPurchasesFound() {
        let outcome = store.restoreOutcome(for: StoreKitError.notEntitled)
        XCTAssertEqual(outcome, .noPurchasesFound)
    }

    func testRestoreOutcomeMapsCancellationErrorToCancelled() {
        let outcome = store.restoreOutcome(for: CancellationError())
        XCTAssertEqual(outcome, .cancelled)
    }

    func testRestoreOutcomeMapsUnknownErrorToOther() {
        struct DummyError: Error {}
        let outcome = store.restoreOutcome(for: DummyError())
        if case .other = outcome {
            // beklenen
        } else {
            XCTFail("bilinmeyen hata .other'a düşmeli, geldi: \(outcome)")
        }
    }
}
