import SwiftUI

/// Paylaşılabilir "bugünün vakitleri" kartı (WhatsApp aile grupları vb.). Organik
/// büyüme: alt kısımda uygulama adı + vaadi (reklamsız/takipsiz) + App Store adresi
/// HER ZAMAN görünür. Renkler sabit (tema/koyu mod'dan bağımsız) — görüntü her cihazda
/// aynı çıksın. Ramazan'da sahur/iftar öne çıkar.
struct ShareCardView: View {
    let placeName: String
    let dateText: String
    let hicriText: String?
    let times: [(prayer: Prayer, text: String)]
    let ramadanDay: Int?

    static let size = CGSize(width: 1080, height: 1350)
    private static let gold = Color(red: 0.85, green: 0.72, blue: 0.40)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(ramadanDay.map { "RAMAZAN · \($0). GÜN" } ?? "SEKİNE")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(Self.gold)
                Text(placeName)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(dateText)
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                if let hicriText {
                    Text(hicriText)
                        .font(.system(size: 32, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(.top, 90)

            VStack(spacing: 0) {
                ForEach(times, id: \.prayer) { item in
                    let highlight = isHighlighted(item.prayer)
                    HStack {
                        Text(Self.label(item.prayer, ramadan: ramadanDay != nil))
                            .font(.system(size: 46, weight: highlight ? .bold : .medium, design: .rounded))
                        Spacer()
                        Text(item.text)
                            .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(highlight ? Self.gold : .white)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 44)
                    if item.prayer != times.last?.prayer {
                        Rectangle().fill(.white.opacity(0.15)).frame(height: 2).padding(.horizontal, 44)
                    }
                }
            }
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.horizontal, 70)
            .padding(.top, 50)

            Spacer(minLength: 20)

            VStack(spacing: 8) {
                Text("Sekine · Reklamsız, takipsiz namaz vakitleri")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("App Store'da “Sekine: Ezan ve Namaz Vakti”")
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 70)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(colors: [Color(red: 0.18, green: 0.61, blue: 0.51),
                                    Color(red: 0.12, green: 0.43, blue: 0.36),
                                    Color(red: 0.055, green: 0.18, blue: 0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func isHighlighted(_ prayer: Prayer) -> Bool {
        guard ramadanDay != nil else { return false }
        return prayer == .fajr || prayer == .maghrib
    }

    /// Ramazan'da imsak/akşam, halk dilindeki adlarıyla (sahur bitişi/iftar).
    static func label(_ prayer: Prayer, ramadan: Bool) -> String {
        guard ramadan else { return prayer.displayName }
        switch prayer {
        case .fajr: return "İmsak (sahur sonu)"
        case .maghrib: return "Akşam (iftar)"
        default: return prayer.displayName
        }
    }
}

enum ShareCardRenderer {
    /// Hicri 9. ay (Ramazan). Bağımsız dal olduğu için `RamadanInfo`'ya bağımlı değil;
    /// ikisi birleşince tek sabite indirilebilir.
    private static let ramadanHicriMonth = 9

    /// Bugünün vakitlerinden kart görüntüsü. `ImageRenderer` ana aktörde çalışır.
    @MainActor
    static func image(placeName: String, day: PrayerDay, timeZone: TimeZone) -> UIImage? {
        // Ramazan günü Diyanet'in hicri verisinden (hicriMonth==9); veri yoksa normal kart.
        let ramadanDay = day.hicriMonth == Self.ramadanHicriMonth ? day.hicriDay : nil
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "tr_TR")
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = timeZone   // konumun saati (yurt dışında cihazınki değil)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR")
        dateFormatter.dateFormat = "d MMMM yyyy EEEE"
        dateFormatter.timeZone = timeZone

        let times: [(prayer: Prayer, text: String)] = Prayer.ordered.compactMap { prayer in
            day.time(for: prayer).map { (prayer, timeFormatter.string(from: $0)) }
        }
        let view = ShareCardView(
            placeName: placeName,
            dateText: dateFormatter.string(from: day.dayStart),
            hicriText: day.hicriDate,
            times: times,
            ramadanDay: ramadanDay)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1   // 1080×1350 piksel, cihaz ölçeğinden bağımsız
        return renderer.uiImage
    }
}
