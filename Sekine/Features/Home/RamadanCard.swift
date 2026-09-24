import SwiftUI

/// Ramazan modu kartı: Ramazan'da sahur/iftar geri sayımı, Ramazan öncesi (yüklü
/// ~32 günlük pencere içinde) "Ramazan'a N gün kaldı" bandı. Hesap tamamen
/// `RamadanInfo`'da (saf, test edilmiş); bu görünüm yalnızca sunum. Ramazan değilse
/// ya da hicri veri yoksa hiçbir şey çizmez.
struct RamadanCard: View {
    @EnvironmentObject private var settings: AppSettings
    let schedule: PrayerSchedule

    var body: some View {
        // Saniyelik zaman çizelgesi: iftar anı geçince faz kendiliğinden "sahur"a döner.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            if let info = RamadanInfo.current(schedule: schedule, now: now) {
                activeCard(info, now: now)
            } else if let days = RamadanInfo.daysUntilStart(schedule: schedule, now: now) {
                countdownBanner(days: days)
            }
        }
    }

    private func activeCard(_ info: RamadanInfo, now: Date) -> some View {
        VStack(spacing: 8) {
            Text("RAMAZAN · \(info.dayNumber). GÜN")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Palette.gold)
            Text(info.phase == .untilIftar ? "İftara kalan süre" : "İmsağa (sahur sonu) kalan süre")
                .font(SekineFont.caption(settings.fontScale))
                .foregroundStyle(Palette.textSecondary)
            Text(CountdownFormatter.string(from: now, to: info.target))
                .font(SekineFont.countdown(settings.fontScale))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Label(Self.timeFormatter.string(from: info.target),
                  systemImage: info.phase == .untilIftar ? "sunset.fill" : "moon.stars.fill")
                .font(SekineFont.row(settings.fontScale))
                .foregroundStyle(Palette.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .sekineCard()
        .accessibilityElement(children: .combine)
    }

    private func countdownBanner(days: Int) -> some View {
        Label("Ramazan'a \(days) gün kaldı", systemImage: "moon.stars.fill")
            .font(SekineFont.row(settings.fontScale))
            .foregroundStyle(Palette.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .sekineCard()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()
}
