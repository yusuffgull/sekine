import SwiftUI

struct QiblaView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var qibla = QiblaManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(spacing: 28) {
                    Text("Kıble Yönü")
                        .font(SekineFont.title(settings.fontScale))
                        .foregroundStyle(Palette.textPrimary)

                    compass

                    VStack(spacing: 4) {
                        Text("\(Int(qibla.qiblaBearing.rounded()))°")
                            .font(SekineFont.hugeTime(settings.fontScale).monospacedDigit())
                            .foregroundStyle(Palette.accent)
                        Text("Kuzeyden Kâbe yönüne açı")
                            .font(SekineFont.caption(settings.fontScale))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    if !qibla.headingAvailable {
                        Text("Pusula bu cihazda kullanılamıyor. Yukarıdaki açı, kuzeye göre kıble yönünü gösterir.")
                            .font(SekineFont.caption(settings.fontScale))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text("Telefonu düz tutun ve oku yeşil işarete hizalayın.")
                            .font(SekineFont.caption(settings.fontScale))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationBarHidden(true)
        }
        .onAppear { qibla.start(from: settings.location) }
        .onDisappear { qibla.stop() }
    }

    private var compass: some View {
        ZStack {
            Circle()
                .fill(Palette.card)
                .overlay(Circle().strokeBorder(Palette.separator, lineWidth: 2))

            // Sabit kıble işareti (üstte yeşil)
            VStack {
                Image(systemName: "location.north.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                Spacer()
            }
            .padding(12)

            // Dönen kıble oku: (kıble açısı - cihaz yönü)
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 90))
                .foregroundStyle(Palette.gold)
                .rotationEffect(.degrees(qibla.qiblaBearing - qibla.heading))
                .animation(.easeInOut(duration: 0.2), value: qibla.heading)
        }
        .frame(width: 260, height: 260)
    }
}
