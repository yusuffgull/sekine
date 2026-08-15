import SwiftUI
import StoreKit

/// Ömürlük "Sekine Premium" satın alma ekranı. Çekirdek ibadet özellikleri ücretsiz;
/// burada yalnızca zenginleştirmeler açılır.
struct PaywallView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false

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
        if let product = store.premiumProduct {
            Button {
                Task {
                    isPurchasing = true
                    let ok = await store.purchase(product)
                    isPurchasing = false
                    if ok { dismiss() }
                }
            } label: {
                HStack {
                    if isPurchasing { ProgressView().tint(.white) }
                    Text(isPurchasing ? "İşleniyor…" : "Premium'u Aç — \(product.displayPrice)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isPurchasing)
        } else if store.isLoadingProducts {
            ProgressView().padding()
        } else {
            Text("Ürün şu an yüklenemedi. Daha sonra tekrar deneyin.")
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var restoreButton: some View {
        Button("Satın alımları geri yükle") {
            Task { await store.restore() }
        }
        .buttonStyle(SecondaryButtonStyle())
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
            Text("Tek seferlik ödeme, ömür boyu. Aile paylaşımı destekli.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
