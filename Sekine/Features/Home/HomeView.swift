import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PrayerTimeStore

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if store.today != nil {
                        nextPrayerCard
                        todayList
                    } else if store.isLoading {
                        ProgressView("Vakitler yükleniyor…")
                            .padding(.top, 60)
                    } else {
                        emptyState
                    }
                    if let error = store.errorMessage {
                        Text(error)
                            .font(SekineFont.caption(settings.fontScale))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .refreshable {
                if let loc = settings.location {
                    await store.refresh(location: loc, settings: settings)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            if let name = settings.location?.name {
                Label(name, systemImage: "mappin.circle.fill")
                    .font(SekineFont.row(settings.fontScale))
                    .foregroundStyle(Palette.accent)
            }
            Text(Self.dateFormatter.string(from: Date()))
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
            if let hicri = store.today?.hicriDate {
                Text(hicri)
                    .font(SekineFont.caption(settings.fontScale))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
            }
        }
        .padding(.top, 8)
    }

    // MARK: Sonraki vakit + canlı geri sayım
    private var nextPrayerCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let next = store.schedule?.nextTime(after: now)
            VStack(spacing: 10) {
                Text("SONRAKİ VAKİT")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.textSecondary)
                if let next {
                    HStack(spacing: 10) {
                        Image(systemName: next.prayer.systemImage)
                        Text(next.prayer.displayName)
                    }
                    .font(SekineFont.hugeTime(settings.fontScale))
                    .foregroundStyle(Palette.textPrimary)

                    Text(Self.timeFormatter.string(from: next.date))
                        .font(SekineFont.row(settings.fontScale))
                        .foregroundStyle(Palette.accent)

                    Text(CountdownFormatter.string(from: now, to: next.date))
                        .font(SekineFont.countdown(settings.fontScale))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                    Text("kaldı")
                        .font(SekineFont.caption(settings.fontScale))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("Bugünün vakitleri tamamlandı.")
                        .font(SekineFont.row(settings.fontScale))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .sekineCard(active: true)
        }
    }

    // MARK: Bugünün tüm vakitleri
    private var todayList: some View {
        let now = Date()
        let current = store.schedule?.currentTime(at: now)
        let next = store.schedule?.nextTime(after: now)
        return VStack(spacing: 0) {
            ForEach(Prayer.ordered) { prayer in
                if let time = store.today?.time(for: prayer) {
                    let isNext = next?.prayer == prayer &&
                        Calendar.current.isDateInToday(next?.date ?? .distantPast)
                    let isCurrent = current?.prayer == prayer &&
                        Calendar.current.isDateInToday(current?.date ?? .distantPast)
                    HStack {
                        Image(systemName: prayer.systemImage)
                            .foregroundStyle(isNext ? Palette.accent : Palette.textSecondary)
                            .frame(width: 30)
                        Text(prayer.displayName)
                            .font(SekineFont.row(settings.fontScale))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(Self.timeFormatter.string(from: time))
                            .font(SekineFont.row(settings.fontScale).monospacedDigit())
                            .foregroundStyle(isNext ? Palette.accent : Palette.textPrimary)
                    }
                    .fontWeight(isNext ? .bold : .regular)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(isCurrent ? Palette.cardActive : Color.clear)

                    if prayer != Prayer.ordered.last {
                        Divider().background(Palette.separator).padding(.leading, 60)
                    }
                }
            }
        }
        .sekineCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .font(.system(size: 48))
                .foregroundStyle(Palette.textSecondary)
            Text("Vakitler henüz yüklenmedi.")
                .font(SekineFont.row(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
            Button("Yenile") {
                if let loc = settings.location {
                    Task { await store.refresh(location: loc, settings: settings) }
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal, 60)
        }
        .padding(.top, 60)
    }

    // MARK: Formatters
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM EEEE"
        return f
    }()
}

/// Geri sayım metni: "2 sa 14 dk 30 sn" — yaşlı kullanıcı için açık.
enum CountdownFormatter {
    static func string(from now: Date, to target: Date) -> String {
        let total = max(0, Int(target.timeIntervalSince(now)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d sa %02d dk", h, m) }
        if m > 0 { return String(format: "%d dk %02d sn", m, s) }
        return String(format: "%d sn", s)
    }
}
