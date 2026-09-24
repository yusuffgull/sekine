import ActivityKit
import Foundation

/// Ramazan'da oruç sürerken (imsak→akşam) iftar sayacı Live Activity'sini başlatır,
/// iftar anında/Ramazan dışında sonlandırır. Karar `RamadanInfo`'dan (Diyanet hicri
/// verisi); veri yoksa hiçbir şey başlatılmaz. Kullanıcı Live Activity'leri iOS
/// Ayarlar'dan kapatmışsa (`areActivitiesEnabled == false`) sessizce hiçbir şey yapmaz.
@MainActor
enum IftarLiveActivityManager {
    /// Karar mantığı (ağsız, saf): şimdi ne yapılmalı?
    enum Action: Equatable {
        case none
        case start(dayNumber: Int, iftar: Date)
        case endAll
    }

    nonisolated static func action(schedule: PrayerSchedule?, now: Date, hasActive: Bool) -> Action {
        guard let schedule, let info = RamadanInfo.current(schedule: schedule, now: now),
              info.phase == .untilIftar else {
            return hasActive ? .endAll : .none
        }
        return hasActive ? .none : .start(dayNumber: info.dayNumber, iftar: info.target)
    }

    static func sync(schedule: PrayerSchedule?, placeName: String, now: Date = Date()) {
        let active = Activity<IftarActivityAttributes>.activities
        let decided = action(schedule: schedule, now: now, hasActive: !active.isEmpty)
        #if DEBUG
        NSLog("IftarLiveActivity: karar=\(decided) aktif=\(active.count) plan=\(schedule == nil ? "yok" : "var")")
        #endif
        switch decided {
        case .none:
            break
        case .endAll:
            Task { for a in active { await a.end(nil, dismissalPolicy: .immediate) } }
        case .start(let day, let iftar):
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                #if DEBUG
                NSLog("IftarLiveActivity: Live Activity'ler kapalı (areActivitiesEnabled=false)")
                #endif
                return
            }
            let attrs = IftarActivityAttributes(dayNumber: day, placeName: placeName)
            let content = ActivityContent(state: IftarActivityAttributes.ContentState(iftar: iftar),
                                          staleDate: iftar)
            do {
                let a = try Activity.request(attributes: attrs, content: content, pushType: nil)
                #if DEBUG
                NSLog("IftarLiveActivity: başlatıldı id=\(a.id) gün=\(day)")
                #endif
            } catch {
                #if DEBUG
                NSLog("IftarLiveActivity: başlatılamadı: \(error)")
                #endif
            }
        }
    }
}
