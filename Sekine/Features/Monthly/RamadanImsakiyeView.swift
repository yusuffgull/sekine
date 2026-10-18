import SwiftUI

/// Ramazan imsakiyesi: 30 gün sahur sonu (imsak) + iftar. Kesin (Diyanet) satırlar normal,
/// tahmini satırlar `≈` ve soluk gösterilir; paylaşım kartı da aynı işareti taşır.
struct RamadanImsakiyeView: View {
    let imsakiye: RamadanImsakiye
    let placeName: String

    @EnvironmentObject private var settings: AppSettings
    @State private var shareImage: UIImage?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(imsakiye.rows) { row in rowView(row) }
                        } header: { header }
                    }
                    .sekineCard()
                    if imsakiye.hasEstimates { footnote }
                    shareButton
                }
                .padding()
            }
        }
        .navigationTitle("Ramazan İmsakiyesi")
        .navigationBarTitleDisplayMode(.inline)
        .task { shareImage = RamadanImsakiyeCardRenderer.image(imsakiye: imsakiye, placeName: placeName) }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Gün").frame(width: 44, alignment: .leading)
            Text("Tarih").frame(maxWidth: .infinity, alignment: .leading)
            Text("Sahur sonu").frame(width: 88)
            Text("İftar").frame(width: 70)
        }
        .font(.system(size: 12 * settings.fontScale.multiplier, weight: .semibold, design: .rounded))
        .foregroundStyle(Palette.textSecondary)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(Palette.card)
    }

    private func rowView(_ row: RamadanImsakiye.Row) -> some View {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = row.timeZone
        let isToday = cal.isDateInToday(row.date)
        let timeFmt = MonthlyView.formatter("HH:mm", row.timeZone)
        let dateFmt = MonthlyView.formatter("d MMM EEE", row.timeZone)
        let soft = row.isDateEstimated || row.isTimeApproximate
        return HStack(spacing: 4) {
            Text("\(row.isDateEstimated ? "≈" : "")\(row.dayNumber)").frame(width: 44, alignment: .leading)
            Text(dateFmt.string(from: row.date)).frame(maxWidth: .infinity, alignment: .leading)
            Text(timeFmt.string(from: row.fajr)).frame(width: 88)
            Text(timeFmt.string(from: row.maghrib)).frame(width: 70)
        }
        .lineLimit(1).minimumScaleFactor(0.7)
        .font(.system(size: 14 * settings.fontScale.multiplier, weight: isToday ? .bold : .regular, design: .rounded).monospacedDigit())
        .foregroundStyle(isToday ? Palette.accent : (soft ? Palette.textSecondary : Palette.textPrimary))
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(isToday ? Palette.cardActive : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.dayNumber). gün, sahur sonu \(timeFmt.string(from: row.fajr)), iftar \(timeFmt.string(from: row.maghrib))\(soft ? ", yaklaşık" : "")")
    }

    private var footnote: some View {
        Text("≈ ile işaretli günler tahmindir: gün numarası ±1 gün sapabilir, soluk vakitler çevrimiçi hesaplanır (imsak erken, iftar geç olacak şekilde güvenli paylı). Diyanet takvimi yayımlandıkça satırlar kesinleşir; oruç için Diyanet takvimi esastır.")
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder private var shareButton: some View {
        if let shareImage {
            ShareLink(
                item: Image(uiImage: shareImage),
                message: Text("Ramazan imsakiyesi — Sekine, reklamsız ve takipsiz: \(SettingsView.appStoreURL().absoluteString)"),
                preview: SharePreview("Ramazan imsakiyesi", image: Image(uiImage: shareImage))
            ) {
                Label("İmsakiyeyi paylaş", systemImage: "square.and.arrow.up")
                    .font(SekineFont.row(settings.fontScale))
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}

/// Paylaşılabilir 30 günlük imsakiye kartı. Renkler sabit (tema bağımsız); alt kısımda
/// uygulama adı HER ZAMAN görünür, tahmini satırlar `≈` ve açıklamayla işaretlidir.
struct RamadanImsakiyeCardView: View {
    let imsakiye: RamadanImsakiye
    let placeName: String

    static let size = CGSize(width: 1080, height: 1920)
    private static let gold = Color(red: 0.85, green: 0.72, blue: 0.40)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("RAMAZAN İMSAKİYESİ")
                    .font(.system(size: 40, weight: .bold, design: .rounded)).tracking(8)
                    .foregroundStyle(Self.gold)
                Text(placeName)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(.top, 50)

            VStack(spacing: 0) {
                HStack {
                    Text("Gün").frame(width: 120, alignment: .leading)
                    Text("Tarih").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Sahur sonu").frame(width: 240)
                    Text("İftar").frame(width: 190)
                }
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.vertical, 10).padding(.horizontal, 36)
                ForEach(imsakiye.rows) { row in
                    let fmt = MonthlyView.formatter("HH:mm", row.timeZone)
                    let dfmt = MonthlyView.formatter("d MMM EEE", row.timeZone)
                    let soft = row.isDateEstimated || row.isTimeApproximate
                    HStack {
                        Text("\(row.isDateEstimated ? "≈" : "")\(row.dayNumber)").frame(width: 120, alignment: .leading)
                        Text(dfmt.string(from: row.date)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(fmt.string(from: row.fajr)).frame(width: 240)
                        Text(fmt.string(from: row.maghrib)).frame(width: 190)
                    }
                    .font(.system(size: 30, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(soft ? 0.65 : 1))
                    .padding(.vertical, 5).padding(.horizontal, 36)
                }
            }
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .padding(.horizontal, 50).padding(.top, 24)

            Spacer(minLength: 12)

            VStack(spacing: 6) {
                if imsakiye.hasEstimates {
                    Text("≈ tahmindir (±1 gün); Diyanet takvimi esastır.")
                        .font(.system(size: 26, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text("Sekine · Reklamsız, takipsiz namaz vakitleri")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("App Store'da “Sekine: Ezan ve Namaz Vakti”")
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 36)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(colors: [Color(red: 0.18, green: 0.61, blue: 0.51),
                                    Color(red: 0.12, green: 0.43, blue: 0.36),
                                    Color(red: 0.055, green: 0.18, blue: 0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

enum RamadanImsakiyeCardRenderer {
    @MainActor
    static func image(imsakiye: RamadanImsakiye, placeName: String) -> UIImage? {
        let renderer = ImageRenderer(content: RamadanImsakiyeCardView(imsakiye: imsakiye, placeName: placeName))
        renderer.scale = 1
        return renderer.uiImage
    }
}
