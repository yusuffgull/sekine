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
                    ContentUnavailableView("Vakit bulunamadı",
                        systemImage: "calendar",
                        description: Text("Ana ekrandan vakitleri yükleyin."))
                }
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                }
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 4) {
            Text("Gün").frame(width: 54, alignment: .leading)
            ForEach(Prayer.ordered) { p in
                Text(shortName(p)).frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
        .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
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
        var cal = Calendar(identifier: .gregorian)
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
