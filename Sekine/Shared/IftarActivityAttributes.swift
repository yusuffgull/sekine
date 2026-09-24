#if os(iOS)
import ActivityKit
import SwiftUI

/// Ramazan iftar geri sayımı Live Activity'si — uygulama ve widget uzantısı ortak
/// kullanır (bu yüzden Shared). Geri sayım `Text(timerInterval:)` ile SİSTEM tarafından
/// çizilir: uygulama arka planda çalışmasa da saniye saniye akar, güncelleme gerekmez.
struct IftarActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// İftar (akşam) anı.
        var iftar: Date
    }
    var dayNumber: Int
    var placeName: String
}

/// Kilit ekranı / bildirim gövdesi. Ayrı bir görünüm: `ImageRenderer` ile ekran görüntüsü
/// alınıp yerleşim doğrulanabilsin diye widget'tan bağımsız (Shared'de).
struct IftarLockScreenView: View {
    let dayNumber: Int
    let placeName: String
    let iftar: Date

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sunset.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.40))
            VStack(alignment: .leading, spacing: 2) {
                Text("İftara kalan")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("Ramazan \(dayNumber). gün · \(placeName)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            Text(timerInterval: Date.now...max(iftar, Date.now.addingTimeInterval(1)), countsDown: true)
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
#endif
