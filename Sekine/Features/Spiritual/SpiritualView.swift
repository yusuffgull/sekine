import SwiftUI

/// "Zikir" sekmesi — tesbih, Esmaül Hüsna ve dualara giriş. Hepsi ücretsiz.
struct SpiritualView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showKaza = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { TesbihView() } label: {
                    row("Tesbih", "circle.grid.cross.fill", "Dijital zikir sayacı")
                }
                NavigationLink { EsmaulHusnaView() } label: {
                    row("Esmaül Hüsna", "sparkles", "99 isim ve anlamı")
                }
                NavigationLink { DuaView() } label: {
                    row("Dualar", "book.fill", "Yaygın dualar ve anlamları")
                }
                NavigationLink { KazaView() } label: {
                    row("Kaza Takibi", "checkmark.circle.fill", "Kaza namazı sayaç ve seri")
                }
                // Kur'an metni/meali uygulamaya gömülmez (lisans); resmî Diyanet sitesine bağlanır
                // (bkz. docs/decisions.md 2026-09-24/27). Tarayıcıda açılır, internet gerekir.
                Link(destination: Self.quranURL) {
                    HStack {
                        row("Kur'an-ı Kerim ve Meal", "text.book.closed.fill", "Diyanet resmî sitesi · tarayıcıda açılır")
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .navigationTitle("Zikir")
            .navigationDestination(isPresented: $showKaza) { KazaView() }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-uiTestShowKaza") { showKaza = true }
                #endif
            }
        }
    }

    private static let quranURL = URL(string: "https://kuran.diyanet.gov.tr/")!

    private func row(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(.footnote).foregroundStyle(Palette.textSecondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Palette.accent)
        }
        .padding(.vertical, 4)
    }
}
