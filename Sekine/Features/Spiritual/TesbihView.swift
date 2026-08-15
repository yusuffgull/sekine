import SwiftUI

/// Dijital tesbih (zikir sayacı) — ücretsiz. Dokun-say, hedef (33/99), zikir döngüsü,
/// haptik, sıfırla. Sayaç ve tur cihazda saklanır.
struct TesbihView: View {
    @EnvironmentObject private var settings: AppSettings

    @AppStorage("tesbih.count") private var count = 0
    @AppStorage("tesbih.target") private var target = 33
    @AppStorage("tesbih.zikirIndex") private var zikirIndex = 0
    @AppStorage("tesbih.rounds") private var rounds = 0

    private static let zikirler = ["Sübhânallah", "Elhamdülillah", "Allâhu Ekber"]

    var body: some View {
        VStack(spacing: 28) {
            Text(Self.zikirler[zikirIndex % Self.zikirler.count])
                .font(SekineFont.title(settings.fontScale))
                .foregroundStyle(Palette.accent)
                .padding(.top, 12)

            counter

            Text("Tamamlanan tur: \(rounds)")
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)

            controls
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Tesbih")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var counter: some View {
        ZStack {
            Circle()
                .stroke(Palette.separator, lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(1, Double(count) / Double(max(1, target))))
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: count)
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 72 * settings.fontScale.multiplier, weight: .bold, design: .rounded)
                        .monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                Text("/ \(target)")
                    .font(SekineFont.caption(settings.fontScale))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: 260, height: 260)
        .contentShape(Circle())
        .onTapGesture { increment() }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Picker("Hedef", selection: $target) {
                Text("33").tag(33)
                Text("99").tag(99)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)

            Button {
                reset()
            } label: {
                Label("Sıfırla", systemImage: "arrow.counterclockwise")
                    .font(SekineFont.caption(settings.fontScale))
            }
            .buttonStyle(.bordered)
            .tint(Palette.accent)
        }
    }

    private func increment() {
        count += 1
        if count >= target {
            count = 0
            rounds += 1
            zikirIndex += 1
            haptic(.heavy)
        } else {
            haptic(.light)
        }
    }

    private func reset() {
        count = 0
        haptic(.medium)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
