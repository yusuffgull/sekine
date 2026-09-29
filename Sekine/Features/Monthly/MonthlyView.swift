import SwiftUI

struct MonthlyView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore
    @StateObject private var approx = ApproxCalendarStore()

    @State private var monthOffset = MonthlyView.initialMonthOffset

    /// DEBUG'da ekran görüntüsü/doğrulama için başlangıç ayı (`-uiTestMonthOffset 4`).
    private static var initialMonthOffset: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-uiTestMonthOffset"), i + 1 < args.count, let n = Int(args[i + 1]) { return n }
        #endif
        return 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                if let days = monthDays, !days.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                ForEach(days) { entry in dayRow(entry) }
                            } header: {
                                columnHeader
                            }
                        }
                        .sekineCard()
                        .padding()
                        if days.contains(where: \.isApproximate) { approxFootnote }
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
                // Diyanet penceresinin ötesi için çevrimiçi "yaklaşık" takvim (sessiz, en iyi çaba).
                if let loc = settings.location { await approx.ensure(for: loc) }
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

    /// Kesin + yaklaşık günler (kesin veri yoksa hiçbiri gösterilmez).
    private var entries: [MonthlyEntry] {
        guard let schedule = store.schedule else { return [] }
        var approxDays: [PrayerDay] = []
        var approxTZ = schedule.timeZone
        // Yaklaşık takvim yalnızca aktif konuma aitse kullanılır (eski konumun verisi karışmasın).
        if let a = approx.schedule, let loc = settings.location,
           let lat = loc.latitude, let lon = loc.longitude,
           abs(a.latitude - lat) < 0.01, abs(a.longitude - lon) < 0.01 {
            approxDays = a.days
            approxTZ = a.timeZone
        }
        return ApproxCalendar.merge(exact: schedule.days, exactTimeZone: schedule.timeZone,
                                    approx: approxDays, approxTimeZone: approxTZ)
    }

    private func monthKey(_ e: MonthlyEntry) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = e.timeZone
        let c = cal.dateComponents([.year, .month], from: e.day.dayStart)
        return c.year! * 12 + (c.month! - 1)
    }

    /// Bugüne göre ay farkı (0 = bu ay) — bugünün ayı, konumun saat diliminde hesaplanır.
    private func currentMonthKey() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = store.schedule?.timeZone ?? .current
        let c = cal.dateComponents([.year, .month], from: Date())
        return c.year! * 12 + (c.month! - 1)
    }

    /// Yüklü verinin kapsadığı ay aralığı (bugüne göre ay farkı olarak).
    private var monthBounds: (min: Int, max: Int)? {
        let keys = entries.map(monthKey)
        guard let lo = keys.min(), let hi = keys.max() else { return nil }
        let cur = currentMonthKey()
        return (lo - cur, hi - cur)
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

    private func dayRow(_ entry: MonthlyEntry) -> some View {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = entry.timeZone
        let day = entry.day
        let isToday = cal.isDateInToday(day.dayStart)
        let timeFmt = Self.formatter("HH:mm", entry.timeZone)
        let dayFmt = Self.formatter("d EEE", entry.timeZone)
        return HStack(spacing: 4) {
            Text(dayFmt.string(from: day.dayStart))
                .frame(width: 54, alignment: .leading)
                .foregroundStyle(isToday ? Palette.accent : Palette.textPrimary)
                .fontWeight(isToday ? .bold : .regular)
            ForEach(Prayer.ordered) { p in
                Text(day.time(for: p).map(timeFmt.string(from:)) ?? "–")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(entry.isApproximate ? Palette.textSecondary : Palette.textPrimary)
            }
        }
        // Yoğun tablo: büyük fontta hücreler sığmazsa satır atlamak yerine küçülsün.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .font(.system(size: 13 * settings.fontScale.multiplier, weight: .regular, design: .rounded).monospacedDigit())
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(isToday ? Palette.cardActive : Color.clear)
        .accessibilityLabel(entry.isApproximate ? "Yaklaşık vakitler" : "")
    }

    private var approxFootnote: some View {
        Text("≈ Soluk satırlar çevrimiçi hesaplanan yaklaşık vakitlerdir (imsak erken, iftar geç olacak şekilde güvenli paylı). Diyanet vakitleri yayımlandıkça günler kesinleşir; oruç ve namaz için Diyanet takvimi esastır.")
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.bottom)
    }

    private var monthDays: [MonthlyEntry]? {
        let all = entries
        guard !all.isEmpty else { return nil }
        let target = currentMonthKey() + monthOffset
        return all.filter { monthKey($0) == target }
    }

    private var monthTitle: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = store.schedule?.timeZone ?? .current
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        return Self.formatter("MMMM yyyy", cal.timeZone).string(from: base)
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

    private static var formatterCache: [String: DateFormatter] = [:]
    /// (biçim, saat dilimi) başına önbellekli formatter — satır başına yeniden yaratılmaz.
    static func formatter(_ format: String, _ tz: TimeZone) -> DateFormatter {
        let key = format + "|" + tz.identifier
        if let f = formatterCache[key] { return f }
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = format
        f.timeZone = tz
        formatterCache[key] = f
        return f
    }
}
