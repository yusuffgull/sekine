import SwiftUI

/// Dua koleksiyonu — yaygın dualar, okunuş + anlam + kaynak. Ücretsiz.
struct DuaView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        List {
            ForEach(SpiritualContent.duas) { dua in
                VStack(alignment: .leading, spacing: 6) {
                    Text(dua.title)
                        .font(SekineFont.row(settings.fontScale))
                        .foregroundStyle(Palette.accent)
                    Text(dua.reading)
                        .font(SekineFont.caption(settings.fontScale))
                        .foregroundStyle(Palette.textPrimary)
                    Text(dua.meaning)
                        .font(SekineFont.caption(settings.fontScale))
                        .foregroundStyle(Palette.textSecondary)
                    Text(dua.source)
                        .font(.footnote)
                        .foregroundStyle(Palette.gold)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Dualar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
