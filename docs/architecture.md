# Mimari

## Katmanlar

```
App/            SekineApp (entry), AppDelegate (UN delegate), RootView (onboarding gate +
                TabView), BackgroundRefresh (BGAppRefresh + cache'ten yeniden zamanlama)
Shared/         Widget + Watch ile paylaşılan: Prayer, PrayerDay/PrayerSchedule,
                PrayerCache, AppGroup
Core/
  PrayerTimes/  PrayerTimeProvider (protokol), DiyanetProvider (birincil), AladhanProvider,
                LocalCalculationProvider, PrayerTimeStore (beyin: cache→fetch→schedule)
  Notifications/ NotificationManager (izin), RollingScheduler (64-pencere), NotificationSound
  Location/     LocationManager (GPS + reverse geocode + arama),
                DiyanetDirectory (il/ilçe + LocationOverrides.json)
  Storage/      AppSettings (app group UserDefaults)
  Premium/      PremiumProviding + Store (StoreKit 2: ömürlük premium + bağış)
  Kaza/         KazaTracker (kaza namazı sayaç + seri, yerel)
  WatchConnectivity/ WatchSessionManager (iPhone tarafı)
DesignSystem/   Palette + SekineFont + kart stili (tüm renk/font token'ları burada)
Features/       Onboarding, Home, Monthly, Qibla, Spiritual (Zikir), Premium (Paywall),
                Settings
SekineWidget/            WidgetKit extension (Shared model'i okur)
SekineWatch/             watchOS app — Core'u değişmeden kullanır, kendi view'ları +
                         WatchSessionManager (watch tarafı)
SekineWatchComplications/ watch komplikasyonları (watch-lokal PrayerCache'ten okur)
```

Şemalar `project.yml`'deki `schemes:` bloğunda tanımlıdır (Xcode otomatik-şemasına
güvenilmez — bkz. `docs/decisions.md`, 2026-08-23).

## Veri akışı
1. `PrayerTimeStore` açılışta `PrayerCache`'ten yükler.
2. `ensureData` kapsamı kontrol eder; gerekiyorsa `DiyanetProvider` (fallback sırası:
   Aladhan → `LocalCalculationProvider`) ile bir yıllık planı çeker → cache'e yazar.
3. `RollingScheduler` cache'ten gelecek ~60 vakti bildirim olarak kurar.
4. Widget ve Watch komplikasyonları aynı cache'i okur (widget app group üzerinden,
   watch kendi lokal cache'inden).

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
- **Vakit kaynağı değişimi:** yeni bir `PrayerTimeProvider` uygulaması + `PrayerTimeStore`'da
  `primary`'yi değiştir. Başka hiçbir yer değişmez. (Zincir bugün: Diyanet → Aladhan →
  lokal `adhan-swift` fallback.)
- **Premium (Faz 2, tamamlandı):** `PremiumProviding`, StoreKit 2 ile uygulandı (ömürlük
  premium + bağış, abonelik değil); tam ezan `RollingScheduler`'a bildirim olarak eklendi.
- **Apple Watch (Faz E4, tamamlandı):** `SekineWatch` hedefi, Core katmanını değişikliksiz
  kullanıyor; iPhone↔Watch senkronizasyonu `WatchConnectivity` ile (`WatchSessionManager`,
  her iki tarafta).
