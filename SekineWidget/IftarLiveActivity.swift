import ActivityKit
import SwiftUI
import WidgetKit

/// Ramazan iftar sayacı Live Activity'si (kilit ekranı + Dynamic Island).
/// Not: sistem çerçevesi bu ortamda görülemedi; yerleşim `IftarLockScreenView`
/// üzerinden ImageRenderer ile doğrulandı, Dynamic Island cihazda gözle kontrol edilmeli.
struct IftarLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IftarActivityAttributes.self) { context in
            IftarLockScreenView(
                dayNumber: context.attributes.dayNumber,
                placeName: context.attributes.placeName,
                iftar: context.state.iftar)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sunset.fill").font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(context.state.iftar, Date.now.addingTimeInterval(1)),
                         countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("İftara kalan · Ramazan \(context.attributes.dayNumber). gün")
                        .font(.footnote)
                }
            } compactLeading: {
                Image(systemName: "sunset.fill")
            } compactTrailing: {
                Text(timerInterval: Date.now...max(context.state.iftar, Date.now.addingTimeInterval(1)),
                     countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "sunset.fill")
            }
        }
    }
}
