import SwiftUI

struct QiblaView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore
    @StateObject private var qibla = QiblaManager()

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(spacing: 28) {
                    Text("Kıble Yönü")
                        .font(SekineFont.title(settings.fontScale))
                        .foregroundStyle(Palette.textPrimary)

                    if qibla.bearingAvailable {
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
                    } else {
                        // Kıble açısı hesaplanamıyor: yanlış yön göstermektense hiç
                        // göstermeyip konum izni isteriz.
                        needsLocationNotice
                    }

                    if let qiblaTime = store.today?.qiblaTime {
                        VStack(spacing: 2) {
                            Label("Kıble saati \(Self.hmFormatter.string(from: qiblaTime))",
                                  systemImage: "sun.max.fill")
                                .font(SekineFont.caption(settings.fontScale))
                                .foregroundStyle(Palette.gold)
                            Text("Bu saatte güneşe döndüğünüzde tam kıbleye bakarsınız.")
                                .font(SekineFont.caption(settings.fontScale))
                                .foregroundStyle(Palette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
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

    /// Kıble açısı hesaplanamadığında gösterilir. Yanlış bir yön göstermek yerine
    /// kullanıcıdan konum izni istenir; vakitler bundan etkilenmez.
    @ViewBuilder private var needsLocationNotice: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.textSecondary)
            Text("Kıble yönü için konumunuz gerekiyor")
                .font(SekineFont.row(settings.fontScale))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("Doğru yönü gösterebilmek için konumunuzu bilmemiz gerekiyor. Konumunuz cihazınızdan dışarı çıkmaz. Namaz vakitleri konum izni olmadan da çalışmaya devam eder.")
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            if qibla.authorizationStatus == .denied || qibla.authorizationStatus == .restricted {
                Button("Ayarlar'da konum iznini aç") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Konum iznine izin ver") {
                    qibla.requestPermission()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 32)
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
