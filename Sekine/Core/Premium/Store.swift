import Foundation
import StoreKit

/// StoreKit 2 mağaza sarmalayıcısı — backend YOK, cihaz-içi entitlement.
/// Ömürlük "Premium" (non-consumable) + bağış (consumable) ürünlerini yönetir.
@MainActor
final class Store: ObservableObject, PremiumProviding {
    static let lifetimeID = "com.sekineapp.sekine.premium.lifetime"
    static let tipIDs = [
        "com.sekineapp.sekine.tip.small",
        "com.sekineapp.sekine.tip.medium",
        "com.sekineapp.sekine.tip.large"
    ]

    @Published private(set) var premiumProduct: Product?
    @Published private(set) var tipProducts: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var isLoadingProducts = false
    @Published var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Uygulama açıkken gelen (başka cihaz/aile paylaşımı) işlemleri dinle.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
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

    /// Sahip olunan ömürlük Premium entitlement'ını kontrol eder.
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.lifetimeID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPremium = owned
    }

    /// Satın alma. Başarılıysa true. (Bağışlar entitlement vermez; sadece finish edilir.)
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
                await transaction.finish()
                await refreshEntitlements()
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

    /// Önceki satın almaları geri yükler (App Store hesabıyla senkron).
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
