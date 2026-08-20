import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let name = settings.location?.name {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let today = store.today {
                    nextPrayerCard(today)
                    todayList(today)
                } else if store.isLoading {
                    ProgressView("Vakitler yükleniyor…")
                } else {
                    Text(store.errorMessage ?? "Vakitler alınamadı.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Yenile") {
                        Task { await refresh() }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onReceive(timer) { now = $0 }
        .task { await refresh() }
    }

    @ViewBuilder
    private func nextPrayerCard(_ today: PrayerDay) -> some View {
        if let next = store.schedule?.nextTime(after: now) {
            VStack(spacing: 2) {
                Text(next.prayer.displayName)
                    .font(.title3.bold())
                Text(next.date, style: .timer)
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .foregroundStyle(.tint)
                Text(next.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func todayList(_ today: PrayerDay) -> some View {
        VStack(spacing: 4) {
            ForEach(today.times.filter(\.prayer.isNotifiable)) { time in
                HStack {
                    Label(time.prayer.displayName, systemImage: time.prayer.systemImage)
                        .font(.caption)
                    Spacer()
                    Text(time.date, style: .time)
                        .font(.caption.monospacedDigit())
                }
            }
        }
    }

    private func refresh() async {
        guard let loc = settings.location else { return }
        await store.ensureData(for: loc, settings: settings)
    }
}
