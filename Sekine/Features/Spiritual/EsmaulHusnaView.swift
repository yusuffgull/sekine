import SwiftUI

/// Esmaül Hüsna — 99 isim + Türkçe anlam. Ücretsiz.
struct EsmaulHusnaView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""

    private var items: [EsmaName] {
        guard !query.isEmpty else { return SpiritualContent.esmaulHusna }
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return SpiritualContent.esmaulHusna.filter {
            ($0.name + " " + $0.meaning)
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 26, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(SekineFont.row(settings.fontScale))
                            .foregroundStyle(Palette.accent)
                        Text(item.meaning)
                            .font(SekineFont.caption(settings.fontScale))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .searchable(text: $query, prompt: "İsim veya anlam ara")
        .navigationTitle("Esmaül Hüsna")
        .navigationBarTitleDisplayMode(.inline)
    }
}
