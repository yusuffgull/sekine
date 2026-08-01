import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore
    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var location: LocationManager

    @State private var showSearch = false
    @State private var isResolving = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Palette.accent)
                    Text("Sekine")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Namaz vakitleri; sade, huzurlu, güvenilir.")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 16) {
                    promise("checkmark.seal.fill", "Reklamsız", "Hiçbir reklam yok, hiçbir dikkat dağıtıcı yok.")
                    promise("lock.shield.fill", "Gizli", "Verileriniz cihazınızdan çıkmaz. Takip yok.")
                    promise("checkmark.circle.fill", "Diyanet uyumlu", "Diyanet'e göre vakitler, çevrimdışı çalışır.")
                }
                .padding(.horizontal, 8)

                Spacer()

                VStack(spacing: 12) {
                    if let loc = settings.location {
                        Label(loc.name, systemImage: "mappin.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Palette.accent)
                    }
                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: useCurrentLocation) {
                        HStack {
                            if isResolving { ProgressView().tint(.white) }
                            Text(isResolving ? "Konum alınıyor…" : "Konumumu Kullan")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isResolving)

                    Button("Şehir / İlçe Ara") { showSearch = true }
                        .buttonStyle(SecondaryButtonStyle())

                    if settings.location != nil {
                        Button("Başla") { Task { await finish() } }
                            .buttonStyle(PrimaryButtonStyle(color: Palette.gold))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .sheet(isPresented: $showSearch) {
            LocationSearchSheet { place in
                settings.location = place
            }
        }
    }

    private func promise(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Palette.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func useCurrentLocation() {
        errorText = nil
        location.requestPermission()
        isResolving = true
        Task {
            do {
                let loc = try await location.resolveCurrentLocation()
                settings.location = loc
            } catch {
                errorText = "Konum alınamadı. Ayarlar'dan konum iznini açın veya şehir arayın."
            }
            isResolving = false
        }
    }

    private func finish() async {
        _ = await notifications.requestAuthorization()
        if let loc = settings.location {
            await store.refresh(location: loc, settings: settings)
        }
        settings.hasCompletedOnboarding = true
    }
}

// MARK: - Buton stilleri

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.accent)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.15 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
