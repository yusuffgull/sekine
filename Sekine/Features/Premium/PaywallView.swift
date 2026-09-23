import SwiftUI
import StoreKit

/// Ömürlük "Sekine Premium" satın alma ekranı. Çekirdek ibadet özellikleri ücretsiz;
/// burada yalnızca zenginleştirmeler açılır.
struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var purchasingProductID: String?

    private let features: [(String, String)] = [
        ("speaker.wave.3.fill", "Tam ezan sesi (birden fazla müezzin)"),
        ("paintbrush.fill", "Ekstra temalar ve uygulama ikonları"),
        ("book.fill", "Dua, zikir ve Esmaül Hüsna koleksiyonları"),
        ("applewatch", "Apple Watch uygulaması"),
        ("mappin.and.ellipse", "Çoklu konum ve vakit başına özel ses")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    if store.isPremium {
                        ownedBadge
                    } else {
                        buyButton
                        restoreButton
                    }
                    footnote
                }
                .padding(24)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Sekine Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 52))
                .foregroundStyle(Palette.accent)
            Text("Reklamsız ve gizli kalsın")
                .font(SekineFont.title(settings.fontScale))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("Namaz vakitleri, bildirimler ve kıble her zaman ücretsiz. Premium, uygulamayı destekler ve ekstra özellikleri açar.")
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.1) { icon, text in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(Palette.accent)
                        .frame(width: 26)
                    Text(text)
                        .font(SekineFont.caption(settings.fontScale))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .sekineCard()
    }

    @ViewBuilder private var buyButton: some View {
        if store.premiumProduct != nil || store.yearlyProduct != nil {
            VStack(spacing: 10) {
                if let yearly = store.yearlyProduct {
                    purchaseButton(
                        for: yearly,
                        title: "Yıllık — \(yearly.displayPrice)",
                        isPrimary: true,
                        badge: "Önerilen · 7 gün ücretsiz deneme"
                    )
                }
                if let lifetime = store.premiumProduct {
                    purchaseButton(
                        for: lifetime,
                        title: "Ömürlük — \(lifetime.displayPrice)",
                        // İkisi de sunulduğunda yıllık öne çıkar (birincil), ömürlük ikincil
                        // görünür. Yalnızca ömürlük varsa (ör. yıllık ürün henüz ASC'de
                        // onaylanmadan önce) tek başına birincil kalır.
                        isPrimary: store.yearlyProduct == nil,
                        badge: nil
                    )
                }
            }
        } else if store.isLoadingProducts {
            ProgressView().padding()
        } else {
            Text("Ürün şu an yüklenemedi. Daha sonra tekrar deneyin.")
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func purchaseButton(
        for product: Product,
        title: String,
        isPrimary: Bool,
        badge: String?
    ) -> some View {
        VStack(spacing: 4) {
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
            Button {
                Task {
                    isPurchasing = true
                    purchasingProductID = product.id
                    let ok = await store.purchase(product)
                    isPurchasing = false
                    purchasingProductID = nil
                    if ok { dismiss() }
                }
            } label: {
                HStack {
                    if purchasingProductID == product.id { ProgressView().tint(.white) }
                    Text(purchasingProductID == product.id ? "İşleniyor…" : title)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(isPrimary ? AnyButtonStyleBox(PrimaryButtonStyle()) : AnyButtonStyleBox(SecondaryButtonStyle()))
            .disabled(isPurchasing)
        }
    }

    private var restoreButton: some View {
        Button("Satın alımları geri yükle") {
            Task { await store.restore() }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(store.isRestoring)
    }

    private var ownedBadge: some View {
        Label("Premium aktif — teşekkürler!", systemImage: "checkmark.seal.fill")
            .font(SekineFont.row(settings.fontScale))
            .foregroundStyle(Palette.accent)
            .padding()
    }

    private var footnote: some View {
        VStack(spacing: 4) {
            if let err = store.purchaseError {
                Text(err).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            // Apple App Review otomatik yenilenen aboneliklerde bu bilgilerin (süre, fiyat,
            // otomatik yenilenme, deneme süresi) açıkça görünmesini şart koşar (Guideline 3.1.2).
            if store.yearlyProduct != nil {
                Text("Yıllık abonelik otomatik yenilenir, 7 gün ücretsiz deneme içerir. İstediğiniz zaman App Store ayarlarından iptal edebilirsiniz. Ömürlük seçenek tek seferlik ödemedir. İkisi de aile paylaşımını destekler.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Tek seferlik ödeme, ömür boyu. Aile paylaşımı destekli.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
