import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SekineEntry: TimelineEntry {
    let date: Date
    let placeName: String?
    let nextPrayer: Prayer?
    let nextDate: Date?
    let todayTimes: [PrayerTime]
}

struct SekineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SekineEntry {
        SekineEntry(date: Date(), placeName: "İstanbul", nextPrayer: .dhuhr,
                    nextDate: Date().addingTimeInterval(3600), todayTimes: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SekineEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SekineEntry>) -> Void) {
        let now = Date()
        var entries: [SekineEntry] = [makeEntry(at: now)]

        // Sonraki birkaç vakit sınırında yeni entry (next-prayer güncellensin).
        if let schedule = PrayerCache.load() {
            let upcoming = schedule.days.flatMap(\.times)
                .filter { $0.date > now }
                .sorted { $0.date < $1.date }
                .prefix(6)
            for t in upcoming {
                entries.append(makeEntry(at: t.date.addingTimeInterval(1)))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> SekineEntry {
        guard let schedule = PrayerCache.load() else {
            return SekineEntry(date: date, placeName: nil, nextPrayer: nil,
                               nextDate: nil, todayTimes: [])
        }
        let next = schedule.nextTime(after: date)
        let today = schedule.day(containing: date)?.times ?? []
        return SekineEntry(date: date, placeName: schedule.placeName,
                           nextPrayer: next?.prayer, nextDate: next?.date, todayTimes: today)
    }
}

// MARK: - Views

struct SekineWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SekineEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        default: medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = entry.nextPrayer?.displayName {
                Label(name, systemImage: entry.nextPrayer?.systemImage ?? "moon")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
            }
            if let d = entry.nextDate {
                Text(d, style: .time).font(.title2.bold())
                Text(d, style: .timer).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Vakit yok").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let p = entry.placeName {
                Text(p).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SONRAKİ").font(.caption2.bold()).foregroundStyle(.secondary)
                if let name = entry.nextPrayer?.displayName, let d = entry.nextDate {
                    Text(name).font(.headline).foregroundStyle(.tint)
                    Text(d, style: .time).font(.title.bold())
                    Text(d, style: .timer).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Vakit yok").foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                ForEach(entry.todayTimes.filter { $0.prayer != .sunrise }) { t in
                    HStack {
                        Text(t.prayer.displayName).font(.caption2)
                        Spacer()
                        Text(t.date, style: .time).font(.caption2.monospacedDigit().bold())
                    }
                }
            }
        }
    }
}

// MARK: - Widget

struct SekineWidget: Widget {
    let kind = "SekineWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SekineProvider()) { entry in
            SekineWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Namaz Vakti")
        .description("Sonraki vakit ve geri sayım.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SekineWidgetBundle: WidgetBundle {
    var body: some Widget {
        SekineWidget()
    }
}
