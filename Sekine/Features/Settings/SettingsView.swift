import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore
    @EnvironmentObject private var notifications: NotificationManager

    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                notificationSection
                appearanceSection
                widgetSection
                aboutSection
            }
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $showSearch) {
                LocationSearchSheet { place in
                    settings.location = place
                    Task { await store.refresh(location: place, settings: settings) }
                }
            }
            .task { await notifications.refreshStatus() }
        }
    }

    // MARK: Konum
    private var locationSection: some View {
        Section("Konum") {
            HStack {
                Image(systemName: "mappin.circle.fill").foregroundStyle(Palette.accent)
                Text(settings.location?.name ?? "Seçilmedi")
                Spacer()
                Button("Değiştir") { showSearch = true }
            }
        }
    }

    // MARK: Bildirimler
    private var notificationSection: some View {
        Section {
            if notifications.authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Bildirim izni kapalı — açmak için dokunun",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            ForEach(Prayer.ordered.filter(\.isNotifiable)) { prayer in
                Toggle(isOn: Binding(
                    get: { settings.isNotificationEnabled(for: prayer) },
                    set: { settings.setNotification($0, for: prayer); reschedule() }
                )) {
                    Label(prayer.displayName, systemImage: prayer.systemImage)
                }
            }

            Picker("Bildirim Sesi", selection: Binding(
                get: { settings.notificationSound },
                set: { settings.notificationSound = $0; reschedule() }
            )) {
                ForEach(NotificationSound.allCases) { sound in
                    Text(sound.displayName).tag(sound.rawValue)
                }
            }

            Toggle("Sessiz Bildirim", isOn: Binding(
                get: { settings.silentNotifications },
                set: { settings.silentNotifications = $0; reschedule() }
            ))

            Picker("Önceden Hatırlat", selection: Binding(
                get: { settings.preReminderMinutes },
                set: { settings.preReminderMinutes = $0; reschedule() }
            )) {
                Text("Kapalı").tag(0)
                Text("5 dakika önce").tag(5)
                Text("10 dakika önce").tag(10)
                Text("15 dakika önce").tag(15)
                Text("30 dakika önce").tag(30)
            }
        } header: {
            Text("Bildirimler")
        } footer: {
            Text("Vakit bildirimleri çevrimdışı çalışır ve uygulamayı açmasanız da düzenli olarak yenilenir. iOS bildirim sesi 30 saniye ile sınırlıdır; tam ezan yakında eklenecektir.")
        }
    }

    // MARK: Widget
    private var widgetSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ana ekran widget'ı")
                        .foregroundStyle(Palette.textPrimary)
                    Text("Sonraki vakti ve geri sayımı uygulamayı açmadan görün.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                }
            } icon: {
                Image(systemName: "apps.iphone")
                    .foregroundStyle(Palette.accent)
            }
        } header: {
            Text("Widget")
        } footer: {
            Text("Eklemek için: ana ekranda boş bir alana basılı tutun → sol üstteki **+** → **Sekine** → widget'ı seçip ekleyin.")
        }
    }

    // MARK: Görünüm
    private var appearanceSection: some View {
        Section("Görünüm") {
            Picker("Tema", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Yazı Boyutu", selection: $settings.fontScale) {
                ForEach(FontScale.allCases) { Text($0.displayName).tag($0) }
            }
        }
    }

    // MARK: Hakkında
    private var aboutSection: some View {
        Section {
            LabeledContent("Sürüm", value: Self.appVersion)
            HStack {
                Image(systemName: "lock.shield.fill").foregroundStyle(Palette.accent)
                Text("Reklamsız · Verileriniz cihazınızdan çıkmaz")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            if let source = store.schedule?.source {
                LabeledContent("Vakit kaynağı", value: Self.sourceLabel(source))
            }
        } header: {
            Text("Hakkında")
        }
    }

    private func reschedule() {
        Task { await store.rescheduleNotifications(settings: settings) }
    }

    static func sourceLabel(_ source: String) -> String {
        switch source {
        case "diyanet": return "Diyanet (resmi)"
        case "aladhan-13": return "Diyanet yöntemi (yaklaşık)"
        default: return "Yaklaşık (çevrimdışı)"
        }
    }

    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
