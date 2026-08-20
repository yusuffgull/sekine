import SwiftUI
import StoreKit

struct WatchPaywallView: View {
    @EnvironmentObject private var iap: Store
    @State private var isPurchasing = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "applewatch.watchface")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
                Text("Sekine Watch")
                    .font(.headline)
                Text("Ömürlük Premium'un bir parçası.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let errorText {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let product = iap.premiumProduct {
                    Button {
                        Task { await purchase(product) }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                        } else {
                            Text("Ömürlük Premium — \(product.displayPrice)")
                        }
                    }
                    .disabled(isPurchasing)
                } else {
                    ProgressView()
                }

                Button("Satın Almaları Geri Yükle") {
                    Task { await iap.restore() }
                }
                .font(.caption2)
            }
            .padding()
        }
        .task { await iap.loadProducts() }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        errorText = nil
        let success = await iap.purchase(product)
        isPurchasing = false
        if !success { errorText = iap.purchaseError }
    }
}
