import SwiftUI

/// Kaza namazı takibi. Ücretsiz: sayaçlar + seri. Premium: geçmiş istatistik.
/// Tamamen yerel — hiçbir veri cihaz dışına çıkmaz (bkz. `KazaTracker`).
struct KazaView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var kaza: KazaTracker
    @EnvironmentObject private var store: Store

    @State private var showPaywall = false
    @State private var editingPrayer: Prayer?
    @State private var editText = ""

    var body: some View {
        List {
            if kaza.currentStreak > 0 {
                streakBanner
            }
            Section {
                ForEach(KazaTracker.kazaPrayers) { prayer in
                    row(for: prayer)
                }
            } header: {
                Text("Kalan Kaza")
            } footer: {
                Text("Sayıyı düzenlemek için üzerine dokunun. \"Kıldım\" her kayıtta borcu 1 azaltır ve seriye işler.")
            }

            if store.isPremium {
                statsSection
            } else {
                Section {
                    Button { showPaywall = true } label: {
                        Label("Geçmiş istatistik (Premium)", systemImage: "chart.bar.fill")
                            .foregroundStyle(Palette.gold)
                    }
                }
            }
        }
        .navigationTitle("Kaza Takibi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(
            editingPrayer?.displayName ?? "",
            isPresented: Binding(
                get: { editingPrayer != nil },
                set: { if !$0 { editingPrayer = nil } }
            )
        ) {
            TextField("Kalan sayı", text: $editText)
                .keyboardType(.numberPad)
            Button("İptal", role: .cancel) { editingPrayer = nil }
            Button("Kaydet") {
                if let prayer = editingPrayer, let value = Int(editText) {
                    kaza.setRemaining(prayer, to: value)
                }
                editingPrayer = nil
            }
        } message: {
            Text("Bu vakit için kalan kaza sayısını girin.")
        }
    }

    private var streakBanner: some View {
        Section {
            Label("\(kaza.currentStreak) günlük seri", systemImage: "flame.fill")
                .font(SekineFont.row(settings.fontScale))
                .foregroundStyle(Palette.accent)
        }
    }

    private func row(for prayer: Prayer) -> some View {
        HStack {
            Image(systemName: prayer.systemImage)
                .foregroundStyle(Palette.accent)
                .frame(width: 26)
            Text(prayer.displayName)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Button {
                editingPrayer = prayer
                editText = String(kaza.remaining(for: prayer))
            } label: {
                Text("\(kaza.remaining(for: prayer))")
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .frame(minWidth: 36)
            }
            .buttonStyle(.plain)
            Button {
                kaza.logCompletion(prayer)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("Kıldım")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Palette.accent)
            .disabled(kaza.remaining(for: prayer) == 0)
        }
        .padding(.vertical, 2)
    }

    private var statsSection: some View {
        Section {
            statRow("Bu hafta", kaza.completions(inLast: 7))
            statRow("Bu ay", kaza.completions(inLast: 30))
            statRow("Toplam kayıtlı", kaza.completions(inLast: 36500))
        } header: {
            Text("İstatistik")
        }
    }

    private func statRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.textPrimary)
            Spacer()
            Text("\(count)").foregroundStyle(Palette.textSecondary).monospacedDigit()
        }
    }
}
