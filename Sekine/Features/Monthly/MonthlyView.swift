import SwiftUI

struct MonthlyView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore

    @State private var monthOffset = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                if let days = monthDays, !days.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                ForEach(days) { day in dayRow(day) }
                            } header: {
                                columnHeader
                            }
                        }
                        .sekineCard()
                        .padding()
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        .disabled(!canGoPrev)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(!canGoNext)
                }
            }
            .task {
                // Vakit yükleme kullanıcının işi değil: konum varsa otomatik yükle.
                if store.schedule == nil, let loc = settings.location {
                    await store.ensureData(for: loc, settings: settings)
                }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if store.isLoading {
            ProgressView("Vakitler yükleniyor…")
        } else if settings.location == nil {
            ContentUnavailableView("Konum seçilmedi",
                systemImage: "mappin.slash",
                description: Text("Ayarlar'dan konumunuzu seçince aylık vakitler burada görünür."))
        } else {
            // Konum var ama veri henüz yok: .task otomatik yüklemeyi tetikler.
            ProgressView("Vakitler yükleniyor…")
        }
    }

    /// Yüklü verinin kapsadığı ay aralığı (bugüne göre ay farkı olarak).
    private var monthBounds: (min: Int, max: Int)? {
        guard let schedule = store.schedule,
              let first = schedule.days.map(\.dayStart).min(),
              let last = schedule.days.map(\.dayStart).max() else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        let cur = cal.dateComponents([.year, .month], from: Date())
        func diff(_ d: Date) -> Int {
            let c = cal.dateComponents([.year, .month], from: d)
            return (c.year! - cur.year!) * 12 + (c.month! - cur.month!)
        }
        return (diff(first), diff(last))
    }

    private var canGoPrev: Bool { monthOffset > (monthBounds?.min ?? 0) }
    private var canGoNext: Bool { monthOffset < (monthBounds?.max ?? 0) }

    private var columnHeader: some View {
        HStack(spacing: 4) {
            Text("Gün").frame(width: 54, alignment: .leading)
            ForEach(Prayer.ordered) { p in
                Text(shortName(p)).frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 12 * settings.fontScale.multiplier, weight: .semibold, design: .rounded))
        .foregroundStyle(Palette.textSecondary)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Palette.card)
    }

    private func dayRow(_ day: PrayerDay) -> some View {
        let isToday = Calendar.current.isDateInToday(day.dayStart)
        return HStack(spacing: 4) {
            Text(Self.dayFormatter.string(from: day.dayStart))
                .frame(width: 54, alignment: .leading)
                .foregroundStyle(isToday ? Palette.accent : Palette.textPrimary)
                .fontWeight(isToday ? .bold : .regular)
            ForEach(Prayer.ordered) { p in
                Text(day.time(for: p).map(Self.timeFormatter.string(from:)) ?? "–")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        // Yoğun tablo: büyük fontta hücreler sığmazsa satır atlamak yerine küçülsün.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .font(.system(size: 13 * settings.fontScale.multiplier, weight: .regular, design: .rounded).monospacedDigit())
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(isToday ? Palette.cardActive : Color.clear)
    }

    private var monthDays: [PrayerDay]? {
        guard let schedule = store.schedule else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = schedule.timeZone
        guard let base = cal.date(byAdding: .month, value: monthOffset, to: Date()) else { return nil }
        let comps = cal.dateComponents([.year, .month], from: base)
        return schedule.days.filter {
            let dc = cal.dateComponents([.year, .month], from: $0.dayStart)
            return dc.year == comps.year && dc.month == comps.month
        }
    }

    private var monthTitle: String {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        return Self.monthFormatter.string(from: base)
    }

    private func shortName(_ p: Prayer) -> String {
        switch p {
        case .fajr: return "İms"
        case .sunrise: return "Gün"
        case .dhuhr: return "Öğ"
        case .asr: return "İk"
        case .maghrib: return "Ak"
        case .isha: return "Ya"
        }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "HH:mm"; return f
    }()
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "d EEE"; return f
    }()
    static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "MMMM yyyy"; return f
    }()
}
