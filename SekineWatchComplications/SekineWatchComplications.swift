import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SekineComplicationEntry: TimelineEntry {
    let date: Date
    let nextPrayer: Prayer?
    let nextDate: Date?
}

struct SekineComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> SekineComplicationEntry {
        SekineComplicationEntry(date: .now, nextPrayer: .dhuhr, nextDate: Date().addingTimeInterval(3600))
    }

    func getSnapshot(in context: Context, completion: @escaping (SekineComplicationEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SekineComplicationEntry>) -> Void) {
        let now = Date()
        var entries: [SekineComplicationEntry] = [makeEntry(at: now)]

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

    private func makeEntry(at date: Date) -> SekineComplicationEntry {
        // Watch-lokal cache: SekineWatch'ın kendi ağ isteğiyle doldurduğu App Group
        // container'ı — iPhone'un cache'i ile senkron DEĞİL (bkz. plan §1).
        guard let schedule = PrayerCache.load() else {
            return SekineComplicationEntry(date: date, nextPrayer: nil, nextDate: nil)
        }
        let next = schedule.nextTime(after: date)
        return SekineComplicationEntry(date: date, nextPrayer: next?.prayer, nextDate: next?.date)
    }
}

// MARK: - Views

struct SekineComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SekineComplicationEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .accessoryCorner: corner
        default: circular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: entry.nextPrayer?.systemImage ?? "moon.stars.fill")
                    .font(.system(size: 13))
                if let d = entry.nextDate {
                    Text(Self.hm(d)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                }
            }
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = entry.nextPrayer?.displayName, let d = entry.nextDate {
                Label(name, systemImage: entry.nextPrayer?.systemImage ?? "moon.stars.fill")
                    .font(.headline)
                    .widgetAccentable()
                HStack(spacing: 6) {
                    Text(Self.hm(d)).font(.subheadline.bold().monospacedDigit())
                    Text(d, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Namaz vakti").font(.headline)
                Text("Sekine'yi açın").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            if let name = entry.nextPrayer?.displayName, let d = entry.nextDate {
                Text("\(name) \(Self.hm(d))")
            } else {
                Text("Namaz vakti")
            }
        } icon: {
            Image(systemName: entry.nextPrayer?.systemImage ?? "moon.stars.fill")
        }
    }

    /// Infograph tarzı watch yüzlerindeki köşe komplikasyonu — kısa metin + ikon.
    private var corner: some View {
        Image(systemName: entry.nextPrayer?.systemImage ?? "moon.stars.fill")
            .widgetLabel {
                if let d = entry.nextDate {
                    Text(Self.hm(d))
                } else {
                    Text("--:--")
                }
            }
    }

    private static func hm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Widget

struct SekineComplication: Widget {
    let kind = "SekineComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SekineComplicationProvider()) { entry in
            SekineComplicationView(entry: entry)
        }
        .configurationDisplayName("Sekine")
        .description("Sıradaki namaz vakti.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct SekineWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        SekineComplication()
    }
}
