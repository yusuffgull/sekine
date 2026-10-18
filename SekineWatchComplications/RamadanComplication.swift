import WidgetKit
import SwiftUI

// Ramazan sahur/iftar komplikasyonu. Yalnızca Diyanet'in KESİN hicri verisiyle (`RamadanInfo`)
// çalışır; veri yoksa tahmin göstermez. (iPhone widget'ıyla aynı mantık, watch hedefine özel.)

struct RamadanComplicationEntry: TimelineEntry {
    let date: Date
    let info: RamadanInfo?
    let daysUntilStart: Int?
}

struct RamadanComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> RamadanComplicationEntry {
        RamadanComplicationEntry(
            date: .now,
            info: RamadanInfo(dayNumber: 12, phase: .untilIftar, target: Date().addingTimeInterval(7200)),
            daysUntilStart: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RamadanComplicationEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RamadanComplicationEntry>) -> Void) {
        let now = Date()
        var entries = [makeEntry(at: now)]
        if let schedule = PrayerCache.load() {
            let boundaries = schedule.days.flatMap(\.times)
                .filter { ($0.prayer == .fajr || $0.prayer == .maghrib) && $0.date > now }
                .sorted { $0.date < $1.date }
                .prefix(6)
            for t in boundaries { entries.append(makeEntry(at: t.date.addingTimeInterval(1))) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> RamadanComplicationEntry {
        guard let schedule = PrayerCache.load() else {
            return RamadanComplicationEntry(date: date, info: nil, daysUntilStart: nil)
        }
        return RamadanComplicationEntry(
            date: date,
            info: RamadanInfo.current(schedule: schedule, now: date),
            daysUntilStart: RamadanInfo.daysUntilStart(schedule: schedule, now: date))
    }
}

struct RamadanComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RamadanComplicationEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .accessoryCorner: corner
        default: circular
        }
    }

    private var symbol: String {
        entry.info?.phase == .untilSahurEnd ? "moon.stars.fill" : "sunset.fill"
    }

    private func caption(_ info: RamadanInfo) -> String {
        info.phase == .untilIftar ? "İftar" : "İmsak"
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: symbol).font(.system(size: 13))
                if let info = entry.info {
                    Text(Self.hm(info.target)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                } else if let n = entry.daysUntilStart {
                    Text("\(n)g").font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let info = entry.info {
                Label("\(info.dayNumber). gün · \(caption(info))", systemImage: symbol)
                    .font(.caption.bold()).widgetAccentable()
                Text(info.target, style: .timer).font(.title3.bold().monospacedDigit())
                Text(Self.hm(info.target)).font(.caption2).foregroundStyle(.secondary)
            } else if let n = entry.daysUntilStart {
                Label("Ramazan'a \(n) gün", systemImage: "moon.stars.fill").font(.headline)
            } else {
                Label("Ramazan", systemImage: "moon.stars.fill").font(.headline)
                Text("Sahur ve iftar sayacı").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            if let info = entry.info {
                Text("\(caption(info)) \(Self.hm(info.target))")
            } else if let n = entry.daysUntilStart {
                Text("Ramazan'a \(n) gün")
            } else {
                Text("Ramazan")
            }
        } icon: { Image(systemName: symbol) }
    }

    private var corner: some View {
        Image(systemName: symbol)
            .widgetLabel {
                if let info = entry.info { Text(Self.hm(info.target)) } else { Text("--:--") }
            }
    }

    private static func hm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct RamadanComplication: Widget {
    let kind = "SekineRamadanComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RamadanComplicationProvider()) { entry in
            RamadanComplicationView(entry: entry)
        }
        .configurationDisplayName("Ramazan")
        .description("İftara ve sahurun bitişine geri sayım.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
