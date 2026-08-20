import WidgetKit
import SwiftUI

struct SekineComplicationEntry: TimelineEntry {
    let date: Date
}

struct SekineComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> SekineComplicationEntry {
        SekineComplicationEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SekineComplicationEntry) -> Void) {
        completion(SekineComplicationEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SekineComplicationEntry>) -> Void) {
        completion(Timeline(entries: [SekineComplicationEntry(date: .now)], policy: .never))
    }
}

struct SekineComplicationView: View {
    var entry: SekineComplicationEntry

    var body: some View {
        Text("Sekine")
    }
}

struct SekineComplication: Widget {
    let kind: String = "SekineComplication"

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
