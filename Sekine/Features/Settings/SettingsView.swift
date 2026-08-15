import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore
    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var iap: Store

    @State private var showSearch = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                premiumSection
                locationSection
                notificationSection
                extraRemindersSection
                appearanceSection
                widgetSection
                donateSection
                aboutSection
            }
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $showSearch) {
                LocationSearchSheet { place in
                    settings.location = place
                    Task { await store.refresh(location: place, settings: settings) }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task { await notifications.refreshStatus() }
        }
    }

    // MARK: Premium
    @ViewBuilder private var premiumSection: some View {
        Section {
            if iap.isPremium {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium aktif").foregroundStyle(Palette.textPrimary)
                        Text("Desteğiniz için teşekkürler.")
                            .font(.footnote).foregroundStyle(Palette.textSecondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.accent)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sekine Premium").foregroundStyle(Palette.textPrimary)
                            Text("Tam ezan, temalar ve daha fazlası — tek seferlik.")
                                .font(.footnote).foregroundStyle(Palette.textSecondary)
                        }
                    } icon: {
                        Image(systemName: "star.circle.fill").foregroundStyle(Palette.gold)
                    }
                }
            }
        }
    }

    // MARK: Destekle
    @ViewBuilder private var donateSection: some View {
        if !iap.tipProducts.isEmpty {
            Section {
                ForEach(iap.tipProducts, id: \.id) { product in
                    Button {
                        Task { await iap.purchase(product) }
                    } label: {
                        HStack {
                            Text(product.displayName).foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(product.displayPrice).foregroundStyle(Palette.accent)
                        }
                    }
                }
            } header: {
                Text("Destekle")
            } footer: {
                Text("Uygulamayı reklamsız ve gizli tutmamıza destek olabilirsiniz. Bağış hiçbir özelliği kilitlemez.")
            }
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
                set: { newValue in
                    // Premium ses ve kullanıcı premium değilse → paywall, seçimi uygulama.
                    if let sound = NotificationSound(rawValue: newValue),
                       sound.isPremiumSound, !iap.isPremium {
                        showPaywall = true
                        return
                    }
                    settings.notificationSound = newValue
                    reschedule()
                }
            )) {
                ForEach(NotificationSound.allCases) { sound in
                    Text(sound.displayName + (sound.isPremiumSound && !iap.isPremium ? " 🔒" : ""))
                        .tag(sound.rawValue)
                }
            }

            Toggle("Sessiz Bildirim", isOn: Binding(
                get: { settings.silentNotifications },
                set: { settings.silentNotifications = $0; reschedule() }
            ))

            Toggle("Odak modunda da uyar", isOn: Binding(
                get: { settings.breakThroughFocus },
                set: { settings.breakThroughFocus = $0; reschedule() }
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
            Text("\"Odak modunda da uyar\" açıkken bildirimler Rahatsız Etmeyin, Uyku ve Odak modlarını delerek ulaşır; kapalıyken bu modlarda sessize alınır. Vakit bildirimleri çevrimdışı çalışır ve uygulamayı açmasanız da düzenli olarak yenilenir. iOS bildirim sesi 30 saniye ile sınırlıdır; tam ezan yakında eklenecektir.")
        }
    }

    // MARK: Ek Hatırlatmalar
    private var extraRemindersSection: some View {
        Section {
            Toggle("Cuma hatırlatması", isOn: Binding(
                get: { settings.fridayReminder },
                set: { settings.fridayReminder = $0; reschedule() }
            ))
            if settings.fridayReminder {
                hourPicker("Cuma saati", selection: Binding(
                    get: { settings.fridayReminderHour },
                    set: { settings.fridayReminderHour = $0; reschedule() }
                ))
            }

            Toggle("Kandil & bayram tebrikleri", isOn: Binding(
                get: { settings.specialDayGreetings },
                set: { settings.specialDayGreetings = $0; reschedule() }
            ))

            Toggle("Günlük ayet/dua", isOn: Binding(
                get: { settings.dailyVerse },
                set: { settings.dailyVerse = $0; reschedule() }
            ))
            if settings.dailyVerse {
                hourPicker("Ayet/dua saati", selection: Binding(
                    get: { settings.dailyVerseHour },
                    set: { settings.dailyVerseHour = $0; reschedule() }
                ))
            }
        } header: {
            Text("Ek Hatırlatmalar")
        } footer: {
            Text("Cuma hatırlatması, kandil-bayram tebrikleri ve günlük ayet/dua bildirimleri. İstemediğinizi buradan kapatabilirsiniz.")
        }
    }

    private func hourPicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { h in
                Text(String(format: "%02d:00", h)).tag(h)
            }
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
            Picker("Renk Teması", selection: Binding(
                get: { settings.colorTheme },
                set: { newValue in
                    if newValue.isPremium, !iap.isPremium {
                        showPaywall = true
                        return
                    }
                    settings.colorTheme = newValue
                }
            )) {
                ForEach(ColorTheme.allCases) { theme in
                    Text(theme.displayName + (theme.isPremium && !iap.isPremium ? " 🔒" : ""))
                        .tag(theme)
                }
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
