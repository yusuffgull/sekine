import WidgetKit
import SwiftUI

// Ramazan sahur/iftar geri sayım widget'ı. Yalnızca Diyanet'in KESİN hicri verisiyle
// (`RamadanInfo`) çalışır; hicri veri yoksa tahmin göstermez (sessizce "Ramazan dışı" durumu).

struct RamadanEntry: TimelineEntry {
    let date: Date
    let info: RamadanInfo?
    /// Ramazan'a kalan gün (yalnızca yüklü Diyanet penceresi içinde bilinir).
    let daysUntilStart: Int?
}

struct RamadanProvider: TimelineProvider {
    func placeholder(in context: Context) -> RamadanEntry {
        RamadanEntry(date: Date(),
                     info: RamadanInfo(dayNumber: 12, phase: .untilIftar, target: Date().addingTimeInterval(7200)),
                     daysUntilStart: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RamadanEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RamadanEntry>) -> Void) {
        let now = Date()
        var entries = [makeEntry(at: now)]
        if let schedule = PrayerCache.load() {
            // İmsak/akşam sınırlarında yeni entry: faz (sahur sonu ↔ iftar) ve gün numarası güncellensin.
            let boundaries = schedule.days.flatMap(\.times)
                .filter { ($0.prayer == .fajr || $0.prayer == .maghrib) && $0.date > now }
                .sorted { $0.date < $1.date }
                .prefix(6)
            for t in boundaries { entries.append(makeEntry(at: t.date.addingTimeInterval(1))) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> RamadanEntry {
        guard let schedule = PrayerCache.load() else {
            return RamadanEntry(date: date, info: nil, daysUntilStart: nil)
        }
        return RamadanEntry(date: date,
                            info: RamadanInfo.current(schedule: schedule, now: date),
                            daysUntilStart: RamadanInfo.daysUntilStart(schedule: schedule, now: date))
    }
}

struct RamadanWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RamadanEntry

    private static let gold = Color(red: 0.85, green: 0.72, blue: 0.40)

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    private var label: String {
        guard let info = entry.info else { return "Ramazan" }
        return info.phase == .untilIftar ? "İftara kalan" : "Sahurun bitmesine"
    }

    private var symbol: String {
        entry.info?.phase == .untilSahurEnd ? "moon.stars.fill" : "sunset.fill"
    }

    private static func hm(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private var inline: some View {
        Label {
            if let info = entry.info {
                Text("\(info.phase == .untilIftar ? "İftar" : "İmsak") \(Self.hm(info.target))")
            } else if let n = entry.daysUntilStart {
                Text("Ramazan'a \(n) gün")
            } else {
                Text("Ramazan")
            }
        } icon: { Image(systemName: symbol) }
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
                Label("\(info.dayNumber). gün · \(label)", systemImage: symbol)
                    .font(.caption.bold()).widgetAccentable()
                Text(info.target, style: .timer).font(.title3.bold().monospacedDigit())
                Text("\(info.phase == .untilIftar ? "İftar" : "İmsak") \(Self.hm(info.target))")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if let n = entry.daysUntilStart {
                Label("Ramazan'a \(n) gün", systemImage: "moon.stars.fill").font(.headline)
            } else {
                Label("Ramazan", systemImage: "moon.stars.fill").font(.headline)
                Text("Ramazan'da sahur ve iftar sayacı").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let info = entry.info {
                Text("RAMAZAN · \(info.dayNumber). GÜN")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1)
                    .foregroundStyle(Self.gold)
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(info.target, style: .timer)
                    .font(.system(.title, design: .rounded).bold().monospacedDigit())
                    .minimumScaleFactor(0.7).lineLimit(1)
                Spacer()
                Text("\(info.phase == .untilIftar ? "İftar" : "İmsak") \(Self.hm(info.target))")
                    .font(.caption.bold().monospacedDigit())
            } else if let n = entry.daysUntilStart {
                Text("RAMAZAN").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1)
                    .foregroundStyle(Self.gold)
                Text("\(n)").font(.system(size: 44, weight: .bold, design: .rounded))
                Text("gün kaldı").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                Text("RAMAZAN").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1)
                    .foregroundStyle(Self.gold)
                Text("Ramazan'da sahur ve iftar sayacı burada görünür.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RamadanWidget: Widget {
    let kind = "SekineRamadanWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RamadanProvider()) { entry in
            RamadanWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ramazan: Sahur & İftar")
        .description("İftara ve sahurun bitişine geri sayım.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
