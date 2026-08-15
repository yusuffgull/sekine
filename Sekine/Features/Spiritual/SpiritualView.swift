import SwiftUI

/// "Zikir" sekmesi — tesbih, Esmaül Hüsna ve dualara giriş. Hepsi ücretsiz.
struct SpiritualView: View {
    @EnvironmentObject private var settings: AppSettings

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
            }
            .navigationTitle("Zikir")
        }
    }

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
