# Mimari

## Katmanlar

```
App/            SekineApp (entry), AppDelegate (UN delegate), RootView (onboarding gate + TabView),
                BackgroundRefresh (BGAppRefresh + cache'ten yeniden zamanlama)
Shared/         Widget ile paylaşılan: Prayer, PrayerDay/PrayerSchedule, PrayerCache, AppGroup
Core/
  PrayerTimes/  PrayerTimeProvider (protokol), AladhanProvider, LocalCalculationProvider,
                PrayerTimeStore (beyin: cache→fetch→schedule)
  Notifications/ NotificationManager (izin), RollingScheduler (64-pencere), NotificationSound
  Location/     LocationManager (GPS + reverse geocode + arama)
  Storage/      AppSettings (app group UserDefaults)
  Premium/      PremiumGate (v1: FreeTierGate → false)
DesignSystem/   Palette + SekineFont + kart stili (tüm renk/font token'ları burada)
Features/       Onboarding, Home, Monthly, Qibla, Settings (SwiftUI view'lar)
SekineWidget/   WidgetKit extension (Shared model'i okur)
```

## Veri akışı
1. `PrayerTimeStore` açılışta `PrayerCache`'ten yükler.
2. `ensureData` kapsamı kontrol eder; gerekiyorsa `AladhanProvider` (fallback:
   `LocalCalculationProvider`) ile bir yıllık planı çeker → cache'e yazar.
3. `RollingScheduler` cache'ten gelecek ~60 vakti bildirim olarak kurar.
4. Widget aynı cache'i (app group) okur.

## Zamanlar mutlak Date olarak saklanır
API'den gelen "HH:mm" değerleri, günün tarihi + timezone (Europe/Istanbul) ile mutlak
`Date`'e çevrilip öyle saklanır. Böylece timezone hataları ve "negatif geri sayım"
sınıfı buglar önlenir.

## Bildirim güvenilirliği (kritik)
iOS max 64 pending bildirim tutar. `RollingScheduler` her tetiklenişte pending'leri temizler
ve gelecek ilk 60'ı yeniden kurar. Tetikleyiciler: app foreground (`scenePhase`),
`BGAppRefreshTask`, ve bir bildirim önplanda tetiklendiğinde (`willPresent`). Tazeleme
cache'ten okur; ağ gerektirmez.

## Genişleme noktaları
- **Diyanet resmi kaynağı:** yeni bir `PrayerTimeProvider` uygulaması + `PrayerTimeStore`'da
  `primary`'yi değiştir. Başka hiçbir yer değişmez.
- **Abonelik (v1.1):** `PremiumProviding`'i StoreKit 2 ile uygula; tam ezan zamanlamasını
  `RollingScheduler`'a peşpeşe bildirim olarak ekle.
