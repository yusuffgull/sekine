# Handoff

## CURRENT TASK — Faz E4 (Watch app) uygulanıyor, `feat/watch-app` branch'i (20 Ağustos 2026)
Gelir zincirindeki idari engeller büyük ölçüde çözüldü (AB erişilebilirliği doğrulandı,
Paid Apps Agreement imzalandı — bkz. aşağı). Ezan ses dosyası tedariki (lisans araştırması)
kullanıcı kararıyla ertelendi. Faz E4 (Apple Watch companion app) planı Opus ile gözden
geçirilip Sonnet ile uygulanmaya başlandı — detaylı plan: `evet-project-yml-i-inceleyip-watchos-eager-bubble.md`
(`~/.claude/plans/`).

### Faz E4 bu oturumda yapılanlar — Aşama 1, 2, 4 tamam; 3 kod-tamam; 6 uçtan uca DOĞRULANDI
- `project.yml`: `SekineWatch` (watchOS app, standalone, `WKRunsIndependentlyOfCompanionApp:
  true`) + `SekineWatchComplications` (widget extension) hedefleri eklendi. Ana `Sekine`
  hedefine XcodeGen'in üretimde doğrulanmış `embed`/`copy` sözdizimiyle gömüldü.
- Paylaşılan Core kodu (PrayerTimes, Location, Notifications, Premium, Storage, Shared,
  QiblaManager.swift) watch hedefine **değişikliksiz** eklendi — hiçbirinde UIKit yoktu,
  hepsi derlendi.
- Yeni watch-özel dosyalar: `SekineWatchApp.swift`, `WatchRootView.swift`,
  `WatchOnboardingView.swift` (il/ilçe seçici + GPS, DiyanetDirectory üzerinden),
  `WatchHomeView.swift`, `WatchQiblaView.swift`, `WatchPaywallView.swift`,
  `WatchTesbihView.swift` (WKInterfaceDevice haptic), `WatchBackgroundRefresh.swift`
  (`WKApplication.scheduleBackgroundRefresh`, BGTaskScheduler watchOS'ta yok).
- **Komplikasyonlar (Aşama 4) gerçek kodla tamam**: `SekineWatchComplications.swift`
  `SekineWidget.swift`'in accessory view'larından adapte edildi (circular/rectangular/
  inline + watch'a özgü `accessoryCorner`), watch-lokal `PrayerCache`'ten okuyor.
  `.appex` doğru şekilde `SekineWatch.app/PlugIns/` altına gömülmüş (dosya sistemi
  seviyesinde kontrol edildi).
- **Bildirimler (Aşama 3) — extra bildirimler için ayrı config dosyası YOK artık**:
  ilk yazılan `WatchNotificationScheduler.swift` silindi. Gerekçe: `PrayerTimeStore.
  ensureData/refresh` zaten kendi içinde tam settings-bazlı config ile bildirim
  planlıyor; `WatchHomeView`'ın her göründüğünde çağırdığı `ensureData` bu ayrı dosyanın
  kapattığı ekstraları (Cuma/kandil/ayet) sessizce yeniden açıyordu. Çözüm:
  `AppSettings.disableCrossDeviceExtraNotifications()` — watch'ın kendi yerel
  `AppSettings`'inde bu üç bayrağı KALICI kapatır (bootstrap'ta bir kez), böylece
  `PrayerTimeStore`'un mevcut yolu tek doğru kaynak olarak kalıyor, çakışma riski
  yapısal olarak ortadan kalktı.
- **WatchConnectivity iki yönlü, UÇTAN UCA GERÇEK SİMÜLATÖR EŞLEŞTİRMESİYLE DOĞRULANDI**:
  iPhone tarafı `Sekine/Core/WatchConnectivity/WatchSessionManager.swift`
  (`AppSettings`/`Store`'un `objectWillChange`'ini debounce ile dinleyip
  `updateApplicationContext` gönderir), watch tarafı `SekineWatch/Core/WatchSessionManager.swift`
  (context'i uygular, konum değiştiyse `store.ensureData` ile gerçek veri çeker).
  `xcrun simctl pair` ile Apple Watch Series 11 + iPhone 17 simülatörleri eşleştirildi;
  iPhone'da gerçek konum seed'i (Ümraniye/İstanbul, gerçek Diyanet vakitleriyle) verilip
  hiç yerel seed OLMAYAN taze bir Watch kurulumu açıldığında, watch **kendiliğinden**
  onboarding'i atlayıp doğrudan paywall'a geçti — bu, context'in gerçekten iPhone'dan
  Watch'a taşındığının davranışsal kanıtı (ekran görüntüsüyle belgelendi).
- `SekineApp.swift`'e (iPhone) `watchSession.configure(...)` çağrısı eklendi.

### Uygulama sırasında bulunan 3 gerçek sorun (hepsi düzeltildi)
1. **`UNNotificationSound(named:)` watchOS'ta `unavailable`** — özel .caf bildirim sesi
   dosyaları watchOS'ta desteklenmiyor. `NotificationSound.swift` (paylaşılan dosya) içine
   `#if os(watchOS)` eklenip o platformda her zaman sistem varsayılanına düşülüyor. Bu
   yüzden watch hedefinin `Sekine/Resources/Sounds`'a ihtiyacı kalmadı.
2. **Swift 6 strict concurrency**: `AppSettings` `@MainActor` izolasyonlu; watch scheduler
   yardımcı fonksiyonu nonisolated bağlamdan senkron erişmeye çalışıyordu (bu dosya sonradan
   tamamen kaldırıldı, bkz. yukarı).
3. **Bildirim izni her açılışta isteniyordu**: `bootstrap()` her `scenePhase == .active`'te
   `requestAuthorization()` çağırıyordu → sistem izin diyaloğu her seferinde bloke ediyordu.
   iOS app'in gerçek deseni (`OnboardingView.finish()`'te YALNIZCA BİR KEZ) watch'a da
   uygulandı: izin artık yalnızca `WatchOnboardingView.finish(with:)`'te isteniyor,
   `bootstrap()` sadece `refreshStatus()` çağırıyor.

### Doğrulama (bu oturumda fiilen yapıldı, hepsi gerçek simülatör/derleme kanıtlı)
- `xcodebuild -scheme SekineWatch -destination 'platform=watchOS Simulator,...' clean build`
  → **BUILD SUCCEEDED** (komplikasyon extension'ı dahil, temiz derleme).
- `xcodebuild -scheme Sekine ... test` → **12/12 test geçti** (üç ayrı turda), iOS ana
  hedef + Watch embedding + Widget embedding hepsi doğrulandı (regresyon yok).
- Watch app watchOS 26.5 Simulator'a kuruldu, `-uiTestSeedIstanbul` debug argümanıyla
  (iOS app'teki mevcut test hook deseniyle aynı) açıldı: onboarding doğru atlandı,
  **WatchPaywallView doğru render oldu** (Türkçe metin, layout, StoreKit ürün yükleme
  spinner'ı — ekran görüntüsüyle belgelendi), izin diyaloğu artık çıkmıyor.
- `xcrun simctl pair` ile iPhone+Watch simülatör eşleştirmesi kurulup **WatchConnectivity
  uçtan uca gerçek veriyle doğrulandı** (yukarıda detaylı).
- **Ortam kısıtı (değişmedi)**: `xcrun simctl privacy` `notifications` servisini
  desteklemiyor; StoreKit sandbox satın alma testi de headless güvenilir değil (proje
  notlarında zaten böyle işaretliydi) → premium-kilitli ekranlar (Home/Kıble/Zikir) bu
  ortamda görsel doğrulanamadı, yalnızca derleme + kod incelemesiyle doğrulandı. Kıble
  pusulası ayrıca gerçek cihaz gerektiriyor (simülatör gerçek heading üretmiyor).
- **Kalan**: Aşama 3'ün gerçek dedup testi (iki cihazda aynı anda ezan bildirimi tetikleyip
  tek bildirim geldiğini görmek) — bu, gerçek zamanlanmış bildirim + iki cihaz + zaman
  geçmesi gerektirdiğinden bu oturumda test edilmedi, TestFlight/gerçek cihaz aşamasına
  kalıyor. Aşama 7 (ASC hazırlığı) tamamen kod dışı, kullanıcı aksiyonu gerektiriyor.

## ÖNCEKİ — Faz 2 (gelir modeli) neredeyse tamam, PUSH EDİLDİ (15 Ağustos 2026)
v1.2 arşivlendi (App Store Connect'te, henüz submit edilmedi — v1.1 review'ının sonucu
bekleniyor). Bu oturumda Faz 2 (Ömürlük Premium + Bağış, StoreKit 2, backend'siz)
neredeyse tamamlandı ve main'e push'landı (7f5a2b3..60c9ecd):
- Faz A: StoreKit 2 altyapısı (Store, Paywall, Ayarlar Premium+Destekle).
- Faz B: Tam ezan mekanizması (premium ses gate + in-app AdhanPlayer).
- Faz C1: Premium renk temaları (Zümrüt free + 4 premium).
- Faz C2: Çınar'ın tasarımı → ücretsiz alternatif app ikonu.
- Faz D: Ücretsiz "Zikir" sekmesi (tesbih + Esmaül Hüsna 100 + 12 dua) — bilgi ücretsiz ilkesi.
- Faz E1: Çoklu konum (premium yer imleri).
- Faz E2: Vakit-başına özel ses (premium).
- Faz E3: Premium widget accent teması.
KALAN: **Faz E4 — Apple Watch uygulaması** (büyük, yeni watchOS target) — kullanıcının
Claude token limiti sıfırlanınca AYRI oturumda yapılacak.

### Gelir için kullanıcının yapması gerekenler (kod dışı, henüz yapılmadı):
1. ~~ASC Paid Applications Agreement~~ — **imzalandı** (20 Ağu 2026, geçici/başka-iş banka
   hesabıyla, bkz. yukarı). Artık engel değil.
2. Vergi dairesinden **GVK Mükerrer 20/B istisna belgesi** al (şahıs şirketi GEREKMEZ,
   Türkiye'de App Store geliri için özel muafiyet — ~6,5M TL/yıl 2026 limiti). Gelince
   ASC'de IBAN/banka bilgisini güncelle. Aciliyeti düşük (müşteri toplanana kadar gerçek
   gelir yok).
3. Bankada **20/B özel ticari hesap** aç, IBAN'ı vergi dairesine bildir (madde 2 ile birlikte).
4. ASC'de IAP ürünlerini oluştur (kodla birebir ID): `com.sekineapp.sekine.premium.lifetime`
   (Non-Consumable), `...tip.small/medium/large` (Consumable). — Artık bağımsız, hemen yapılabilir.
5. **Ezan ses dosyaları — ERTELENDİ** (20 Ağu 2026, kullanıcı kararı: lisans araştırması
   yorucu/can sıkıcı bulundu, öncelik diğer geliştirmelere kaydı). Araştırma özeti kayıtlı
   (bu oturumun transkriptinde): CC0 adaylar bulundu (Madinah Fajr Azan - Sheikh Faisal
   Numan, archive.org, CC0; Beautiful adhan.ogg, Wikimedia, CC0) ama hiçbiri "makam-bazlı
   5 ayrı vakit" değil — o set (İlhan Tok / Abc Müzik) ticari lisans gerektiriyor. Gerekirse
   ileride: `ezan.caf` (≤30sn bildirim tonu) + `ezan-full.m4a` (in-app tam ezan) →
   `Sekine/Resources/Audio/`. Kod zaten dosyalar eklenince otomatik aktifleşecek şekilde
   yazıldı (gate açık, dosya yoksa özellik sessizce pasif) — bu erteleme hiçbir şeyi bozmaz.
6. AB satış: **çözüldü** — non-trader modunda global erişilebilirlik doğrulandı (İspanya'dan
   test indirmesi başarılı, 20 Ağu 2026).

### Repo görünürlüğü: PUBLIC kalmalı
Support URL + Privacy Policy URL repo'ya bağlı (ASC gereksinimi); private yapılırsa
App Store'daki linkler kırılır. Karar: bilinçli olarak public bırakıldı.

### AB erişilebilirliği: 27 AB ülkesinde "Cannot Sell" idi — ÇÖZÜLDÜ, DOĞRULANDI (20 Ağu 2026)
Sebep: DSA Trader Status tamamlanmamıştı. Kullanıcı "non-trader" seçti → global erişilebilirlik
açıldı. Doğrulama: İspanya'daki bir arkadaş uygulamayı indirip kullanabildi. Kapandı.

### ASC Paid Applications Agreement — imzalandı (20 Ağu 2026, geçici banka hesabıyla)
Kullanıcı formu, elindeki (başka bir işine ait) mevcut banka hesabıyla doldurup gönderdi —
istisna belgesi/20-B hesabı beklemeden. Gerekçe: ilk aşamada müşteri toplanana kadar zaten
gerçek gelir oluşmayacak, bu yüzden hesap sonradan güncellenebilir bir risk değil. Plan:
20/B istisna belgesi + özel ticari hesap gelince ASC'de IBAN/banka bilgisi güncellenecek.
Bu adım artık gelir zincirinin önünde engel DEĞİL; kalan kapılar bağımsız ilerleyebilir
(IAP ürün ID'leri ASC'de tanımlanabilir, ezan ses dosyaları eklenebilir).

### v1.1 (build 4) — REVIEW'DA, push'landı:

### Bu turda yapılanlar (hepsi build+test doğrulandı, 10/10 test, simülatör görsel):
1. Bildirim metinleri: tüm vakitlere tutarlı temenni; Güneş bildirimi zaten kapalıydı
   (isNotifiable=false), ölü metin temizlendi.
2. Onboarding "ilçe bulunamadı" hatasından "Diyanet" kelimesi çıkarıldı.
3. Yazı boyutu artık TÜM ekranlarda: Home/Qibla zaten SekineFont; köke DynamicTypeSize
   (Settings/Onboarding/Search), Monthly sabit hücreler çarpan + lineLimit(1)+
   minimumScaleFactor (XL'de satır atlamasın). DEBUG hook: -uiTestFontScale.
4. Aylık: konum varsa OTOMATİK yüklenir; ay gezinme yüklü veriyle sınırlı (chevron
   disable); "ana ekrandan yükleyin" mesajı kaldırıldı, net boş-durum kondu.
5. Widget tanıtımı: Onboarding'de 4. vaat satırı + Ayarlar'da "Widget" bölümü (kurulum
   yönergesi).
6. **İl/ilçe verisi (önemli):** kaynak = ezanvakti.emushaf.net (Diyanet aynası). Aynada
   bazı isimler ASCII-hasarlı (Arnavutkoy) ve İstanbul'da ~20 idari ilçe yok (Üsküdar,
   Ataşehir…) çünkü Diyanet onları merkez İstanbul (9541) altında veriyor.
   Çözüm: bundle'lı `Sekine/Core/Location/LocationOverrides.json` → 434 GÖRÜNEN-ad
   düzeltmesi (aynı IlceID → aynı vakit, kanıtlanabilir güvenli) + İstanbul eksik
   ilçeleri 9541'e alias. Üretim scripti: emushaf ↔ yetkili il/ilçe (sh4dowb gist)
   normalize-eşleştirme; her fix orijinalle AYNI normalize kimliğine sahip.
   KARAR (kullanıcı onayı): toptan "tüm illere ilçe ekleme" YAPILMADI — Antalya/Muğla
   gibi coğrafi geniş illerde eksik ilçeyi merkeze bağlamak yanlış vakit riski taşır.
   Diğer illerde eksik ilçe talebi gelirse il-bazlı doğrulanarak eklenmeli.

### Faz 1 gönderim referansı (App Store):
Apple ID: 6796900944. Team: 33L468BTR2. Repo PUBLIC.

### Gönderim sırasında çözülen sorunlar (ileride tekrarında referans):
- 90474 (iPad orientation) → TARGETED_DEVICE_FAMILY=1 her hedefte (XcodeGen proje base'i
  target ayarını ezmiyor, TARGET seviyesine yazılmalı). Build 2.
- codesign "resource fork/detritus" → DerivedData'yı iCloud'lu ~/Documents DIŞINA ver.
- ASC "Username/Password required" → App Review'da "Sign-in required" kutusu kapatılmalı.
- İkon: even-odd hilal "çift hilal" görünüyordu → clip-ile-tek-hilal C3 konsepti, build 3.

### Sonraki (kullanıcı isterse):
- Faz 1.1: StoreKit 2 aboneliği + tam ezan (peşpeşe bildirim). PremiumGate hazır.
- Faz 2: Android (Kotlin), globalleşme, ayet paylaşımı, dini bulmacalar.

### ASC'de kaldığı yer — devam adımları (kullanıcı, interaktif):
1. App Information: Subtitle "Reklamsız, gizli namaz vakti"; Category Lifestyle (+Reference).
2. 1.0 sürüm sayfası: Description + Keywords (docs/store-submission.md'de hazır),
   Support URL = https://github.com/yusuffgull/sekine
3. Screenshots (6.9"): store/screenshots/ içindeki 5 PNG.
4. App Privacy = Data Not Collected · Pricing = Free · Age Rating = 4+.
5. Xcode: hedef "Any iOS Device" → Product → Archive → Distribute → App Store Connect →
   Upload. İşlenince sürüme build ekle → Submit for Review.
   NOT: Xcode GUI varsayılan DerivedData (~/Library) kullanır → iCloud xattr sorunu YOK.
   (CLI'dan device build yaparken -derivedDataPath'i iCloud'lu Documents DIŞINA ver.)

### Açık işler:
- Privacy Policy URL Apple ileride isteyebilir → repo'ya PRIVACY.md eklenebilir (yapılmadı).
- Ödemeli Apple Developer Program üyeliği şart (Distribute'te App Store yoksa sebebi bu).

## DONE
- Native SwiftUI (iOS 17+) tam uygulama: Onboarding, Home (canlı geri sayım), Aylık
  imsakiye, Kıble, Ayarlar, WidgetKit widget. 5 ekran da simülatörde görsel doğrulandı.
- **Vakit kaynağı = birebir Diyanet** (DiyanetProvider, ezanvakti/namazvakti.diyanet.gov.tr
  mirror, il/ilçe ID bazlı). Doğrulama: Aladhan method=13 Akşam/Yatsı'da 1-2 dk erkendi →
  Diyanet resmi veriye geçildi. Zincir: Diyanet → Aladhan → lokal (adhan-swift).
- Konum: il/ilçe picker + GPS→ilçe eşleştirme. RollingScheduler (64-pencere) + 3 tetikleyici.
- Reklamsız, backend'siz, tracking'siz. İkon + orijinal chime.caf.
- `xcodebuild build` başarılı; 9/9 unit test geçti. GitHub'a push edildi (private).
- App Store 6.9" ekran görüntüleri: `store/screenshots/` (1320x2868, 5 adet).

## NEXT
1. **Faz E4 — Apple Watch uygulaması** (yeni watchOS target, premium özellik, büyük iş) —
   sıradaki geliştirme.
2. Gelir zinciri (kod dışı, kullanıcı takip ediyor): 20/B istisna belgesi + özel hesap
   gelince ASC'de IBAN güncelle; IAP ürün ID'leri ASC'de tanımlanabilir (bağımsız, hemen
   yapılabilir); ezan ses dosyaları ERTELENDİ (bkz. yukarı).
3. (Opsiyonel) İstanbul dışı illerde eksik ilçe talebi gelirse il-bazlı doğrulayarak alias ekle.

## BLOCKERS
Yok.

## BEST AGENT NOW
Claude — ürün/veri kararı gerektiren işler sürüyor.
