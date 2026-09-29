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
API'den gelen "HH:mm" değerleri, günün tarihi + timezone ile mutlak `Date`'e çevrilip
öyle saklanır. Böylece timezone hataları ve "negatif geri sayım" sınıfı buglar önlenir.

**Timezone kaynağı (2026-09-24'ten beri, yurtdışı desteği):** `Europe/Istanbul` SABİT
DEĞİL — `DiyanetProvider` her günün GERÇEK UTC ofsetini Diyanet API'sinin kendi
`MiladiTarihUzunIso8601` alanından ayrıştırır (yalnızca ayrıştırılamazsa Istanbul'a
düşer). `LocalCalculationProvider` (ağsız fallback) cihazın kendi saat dilimini
kullanır. Detay ve bilinen dar sınır: `docs/decisions.md` (2026-09-24).

## Bildirim güvenilirliği (kritik)
iOS max 64 pending bildirim tutar. `RollingScheduler` her tetiklenişte pending'leri temizler
ve gelecek ilk 60'ı yeniden kurar. Tetikleyiciler: app foreground (`scenePhase`),
`BGAppRefreshTask`, ve bir bildirim önplanda tetiklendiğinde (`willPresent`). Tazeleme
cache'ten okur; ağ gerektirmez.

## Genişleme noktaları
- **Vakit kaynağı değişimi:** yeni bir `PrayerTimeProvider` uygulaması + `PrayerTimeStore`'da
  `primary`'yi değiştir. Başka hiçbir yer değişmez. (Zincir bugün: Diyanet → Aladhan →
  lokal `adhan-swift` fallback.)
- **Yurtdışı konum (2026-09-24):** `DiyanetDirectory.countries()`/`cities(countryID:)`; GPS ülkeyi otomatik tespit eder, manuel aramada ülke seçici var. Onboarding ve watchOS de aynı ülke seçiciyi kullanır (Diyanet'in tüm ülkeleri).
- **Ramazan modu (2026-09-24):** `Shared/RamadanInfo` — Diyanet hicri verisinden (hicriMonth==9), hicri veri yoksa kapalı.
- **Premium (Faz 2, tamamlandı):** `PremiumProviding`, StoreKit 2 ile uygulandı; tam ezan
  `RollingScheduler`'a bildirim olarak eklendi.
- **Yıllık abonelik (2026-09-24 eklendi):** Ömürlüğün yanına `com.sekineapp.sekine.premium.yearly`
  eklendi. `Store.entitlementProductIDs` ikisini de kapsar — ömürlük VE aktif abonelik
  `.owned` sayılır. Abonelik yenilemesi `Transaction.updates`'ten anında yakalanır; sessiz
  süre dolumu (kullanıcı yenilemedi) ancak bir sonraki app-launch/restore taramasında fark
  edilir — bilinçli v1 sınırı (bkz. `Store.refreshEntitlements()` doc-comment'i).
- **Ramazan/oruç/Live Activity (2026-09-24):** `RamadanInfo` sahur/iftar sayacını besler; oruç günü
  işareti Ramazan kartında; iftar Live Activity (`IftarActivityAttributes`) uygulama içi anahtarla.
- **Paylaşım kartı:** `ImageRenderer` ile filigranlı vakit kartı (Home'dan paylaşılır).
- **Apple Watch (Faz E4, tamamlandı):** `SekineWatch` hedefi, Core katmanını değişikliksiz
  kullanıyor; iPhone↔Watch senkronizasyonu `WatchConnectivity` ile (`WatchSessionManager`,
  her iki tarafta).
