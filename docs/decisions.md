# Kararlar (ADR-lite)

> Yeni girdi en üste. Geçmiş girdiler geriye dönük düzenlenmez.

## 2026-09-08 — RollingScheduler (bildirim planlama): 7 turdan sonra mevcut haliyle kabul

**Karar:** `Sekine/Core/Notifications/RollingScheduler.swift` baştan yazımı, 7 turluk
VISION (GPT) review döngüsünden sonra mevcut haliyle kabul edildi. 72/72 test geçiyor
(3 kez art arda doğrulandı, kilitlenme yok). Misyon: `~/Documents/repos/stark-industries/missions/2026-09-07-sekine-rolling-scheduler.md`.

**Ulaşılan ve doğrulanan kritik garantiler (ana misyon hedefi):** Çoklu-instance
race çözüldü (tek kanonik `RollingScheduler`, composition root `SekineApp.init()`'te).
Stabil identifier + `content.userInfo` fingerprint + otomatik replace ile transactional-
benzeri reconciliation. Artık istenmeyen v2 kayıtlar temizleniyor. Legacy (v1)
migrasyonu gerçek production ID formatlarını (`<prayer>-main/pre-<epoch>`, `holy-
<date>`, `verse-<date>`, `friday-weekly`) doğru hedefliyor. 64-bildirim limiti
gerçek pending sayısından hesaplanıyor, aşım riski deferred'e düşüyor.

**Yol boyunca yakalanan gerçek bir hata (round 4→5 arası):** Round 4'ün eklediği
concurrency testi, sabit-yield varsayımına dayandığı için tüm test suite'ini
GERÇEKTEN kilitledi (300+ saniye asıldı, manuel `pkill` gerekti) — VISION'ın önceden
uyardığı risk gerçekleşti. Kök neden: testin kendi rendezvous mantığı, üretim kodu
değil. Deterministik bir poll (`isTokenQueuedForTesting`) + 5sn zaman aşımıyla
düzeltildi, üretim koduna dokunulmadı. **Ders:** Concurrency testlerinde "N kez
yield et, yeterli olmalı" varsayımı gerçek bir deadlock'a dönüşebilir — her zaman
gözlemlenebilir bir durum sinyali (test-only accessor) + zaman aşımı kullanılmalı.

**Kabul edilen, ÇÖZÜLMEMİŞ bilinen riskler (düşük ciddiyet — bildirim kaybı değil,
nadir BGTask zaman-aşımı kenar durumları; ayrı bir takip turunda ele alınabilir):**
1. **[P2]** Kuyrukta bekleyen expired bir iş hemen tamamlandığında dönen
   `RescheduleResult`'taki sayım (`requested:0, deferred:1`) invariant'ı hafifçe
   bozuyor — kozmetik, davranışı etkilemiyor.
2. **[P1]** `markExpired`'ın TTL tabanlı token temizliği, HÂLÂ AKTİF (henüz
   bitmemiş) bir işin expire bilgisini yanlışlıkla süpürebilir — iş A expire olup
   60 saniyeden uzun sürerse, başka bir işin `markExpired` çağrısı A'nın token'ını
   koşulsuz temizleyebilir, A devam ettiğinde expire olmamış gibi davranabilir.
   Düzeltmesi: aktif ve orphan token'ları ayrı takip etmek gerekir.

**Neden mevcut haliyle kabul edildi:** 7 tur + bir gerçek test-kilitlenmesi
düzeltmesinden sonra azalan getiri noktasına ulaşıldı (StoreKit misyonunda da aynı
desen gözlemlendi — bkz. altındaki girdi). Kalan riskler normal çalışmada bildirim
kaybına yol açmıyor, sadece OS'un BGTask zaman bütçesi dolduğunda nadir bir
zamanlama kenar durumu. Ana misyon hedefi (sessiz bildirim kaybı, çoklu-instance
race, legacy migrasyon) doğrulanmış şekilde kapatıldı.

---

## 2026-09-08 — StoreKit entitlement güvenilirliği: 6 turdan sonra mevcut haliyle kabul

**Karar:** `Sekine/Core/Premium/Store.swift` StoreKit entitlement/restore güvenilirliği
düzeltmesi, 6 turluk VISION (GPT) review döngüsünden sonra mevcut haliyle kabul edildi.
68/68 test geçiyor. Misyon: `~/Documents/repos/stark-industries/missions/2026-09-07-sekine-storekit-entitlement.md`.

**Ulaşılan ve doğrulanan en kritik garanti (ana misyon hedefi):** `.unverified` bir
transaction sonucu ASLA önceden doğrulanmış `owned=true` durumunu ezmiyor — ödeme
yapmış bir kullanıcının premium'u kaybetmesi riski kapatıldı. Ayrıca: revocation
doğru akışa (`Transaction.updates`) taşındı, `finish()` sırası düzeltildi, restore
tek in-flight task'a birleşiyor (normal tamamlanma senaryosunda).

**Kabul edilen, ÇÖZÜLMEMİŞ bilinen riskler (takip gerektirir, ayrı/daha sakin bir
StoreKit turunda ele alınmalı):**
1. **[P1]** `restore()`'un `alreadyOwned` kararı, sync tamamlandıktan SONRA state
   okunarak veriliyor — sync sırasında gerçek bir satın alma `Transaction.updates`
   üzerinden gelirse, restore bunu kendi getirdiği bir sonuç gibi değil `alreadyOwned`
   gibi yanlış raporlayabilir.
2. **[P1]** `restore()`'un sonucu kendi taramasına değil PAYLAŞILAN state'e dayanıyor
   — restore taraması sürerken başka bir `refreshEntitlements()` generation'ı
   artırırsa, restore'un bulduğu gerçek `owned` sonucu atılıp yanlışlıkla
   `.noPurchasesFound` dönebilir.
3. **[P1]** `.indeterminate` durumu hâlâ bazı senaryolarda (Watch'ta cache'te eski
   `false` varsa, veya cache hiç yoksa tek retry sonrası hâlâ unverified'sa) yanlış
   davranabilir — ya paywall gösterip tekrar satın alma sunuyor ya da kalıcı
   "kontrol ediliyor" ekranında takılı kalıyor.
4. **[P2]** Restore hiç dönmeyen bir `syncProvider()`/tarama'da asılı kalırsa
   (`[weak self]` güçlü referansa çevrilip tutulduğu için) `isRestoring` sonsuza
   dek `true` kalabilir, sonraki restore çağrıları aynı asılı task'a bağlanır.
5. **[P2]** `StoreKitError.notEntitled` → `.noPurchasesFound` eşlemesi Apple
   semantiğine aykırı (notEntitled = uygulama entitlement'a sahip değil/dağıtım-
   imzalama sorunu, kullanıcının satın alması yok demek değil) — bu bir
   dağıtım/imzalama hatasını "satın almanız yok" diye yanlış gösterebilir.
6. **[P2]** `Transaction.updates`'teki unverified update olayı tamamen atlanıp
   sadece loglanıyor — `EntitlementState.indeterminate` sözleşmesine göre bu durumun
   state'i (owned korunarak) indeterminate'e geçirmesi gerekirdi.

**Neden mevcut haliyle kabul edildi:** 6 tur derinlemesine review sonrası azalan
getiri noktasına ulaşıldı (RollingScheduler misyonunda da benzer bir desen
gözlemlendi). Kalan riskler "ödeme yapan kullanıcı parayı/erişimi kalıcı kaybeder"
seviyesinde değil — nadir yarış durumları ve restore-akışı UX detayları. Ana
misyon hedefi (entitlement kaybı riski) doğrulanmış şekilde kapatıldı.

**Takip:** Yukarıdaki 6 madde, ayrı bir StoreKit-v2 misyonu olarak ileride ele
alınabilir — özellikle restore'un kendi taramasının sonucunu (paylaşılan state
yerine) doğrudan döndürmesi ve `alreadyOwned` kararının sync ÖNCESİ state'e göre
verilmesi öncelikli olmalı.

---

## 2026-09-08 — İmsakiye çok-ay genişletmesi ERTELENDİ

**Karar:** Aylık imsakiye ekranını 1 aydan birkaç aya genişletme fikri şimdilik
uygulanmayacak, mevcut 32-günlük kayan pencere korunacak.

**Neden:** Mevcut kaynak (ezanvakti.emushaf.net, Diyanet aynası) her zaman "bugünden
itibaren sabit 32 gün" döndürüyor, tarih aralığı parametresi kabul etmiyor — bu bir
tasarım kısıtı, hızlı düzeltilemez. Araştırıldı: Diyanet'in resmi "Awqat Salah" API'si
(awqatsalah.diyanet.gov.tr) tarih aralığını (aylık/yıllık) destekliyor AMA rate-limit'i
(günde 5, ayda 10 istek/konum) kendi backend/cache/proxy katmanını zorunlu kılıyor —
bu, uygulamanın "%100 çevrimdışı & gizli" temel iddiasını değiştiren büyük bir mimari
karar olurdu. Alternatif (Aladhan API, `method=13&annual=true`) backend gerektirmiyor
ama Diyanet'in resmi verisi değil, hesaplama-tabanlı yaklaşık değer — "Diyanet birebir"
iddiasıyla çelişme riski taşıyor.

**Kullanıcı kararı:** Şimdilik dokunma, mevcut pencereyi koru. İleride tekrar
değerlendirilebilir.

## 2026-08-24 — Xcode Cloud: Archive/export yerine Build + Test (dağıtım paketi üretilmiyor)
**Sorun:** Workflow'un Archive action'ı her çalışmada **üç ayrı dağıtım paketi** export
etmeye çalışıyordu (ad-hoc, development, app-store) ve export adımı imzalama/provisioning
yüzünden `exit 70` ile patlıyordu. Arşivin kendisi sorunsuzdu — yerelde `Sekine` şemasıyla
alınan arşivde `Products/Applications/Sekine.app` doğru şekilde üretiliyor, Release
derlemesi temiz. Yani hata kodda değil, imzalamadaydı.
**Karar:** Archive action kaldırıldı; yerine **Build + Test** action'ları kondu (Scheme:
`Sekine`, test için iOS Simulator). Gerekçe: üretilen üç .ipa hiç kullanılmıyor —
release arşivi Xcode'dan elle alınıp yükleniyor. CI'ın gerçek değeri "derleniyor mu +
testler geçiyor mu" sorusunu yanıtlamak; workflow test bile çalıştırmıyordu (16 birim
testi vardı). Böylece CI hem yeşile döndü hem de ilk kez gerçek bir regresyon ağı oldu.
**Not:** Bu değişiklik App Store Connect'teki workflow ayarındadır, repoda değil.
İleride TestFlight'a otomatik build gönderilmek istenirse Archive action geri eklenebilir —
o durumda imzalama sorununun ayrıca çözülmesi gerekir (logs artifact'ından kök neden
okunmalı; muhtemel aday: yerelde otomatik imzalamayla arşiv alınırken profillerin
güncellenip Xcode Cloud'un yönetilen profilleriyle çakışması).

## 2026-08-24 — Koordinat opsiyonel: kıble ASLA doğrulanmamış koordinattan çizilmez
**Sorun:** `LocationSearchSheet` ilçe adını geocode ediyor, başarısız olursa sessizce
`39.0 / 35.0` (Türkiye'nin coğrafi merkezi) saklıyordu. Kıble bu koordinattan hesaplandığı
için kullanıcı, hiçbir uyarı görmeden ~10-15° sapmış "makul görünen" bir yöne yöneliyordu.
`CLGeocoder` çevrimdışıyken ve rate-limit'te başarısız olur — onboarding sırasında
gerçekçi. Ayrıca `QiblaManager`, konum hiç yokken `qiblaBearing`'i 0'da bırakıyor, yani
**kuzeyi kıble olarak** gösteriyordu.
**Karar:** `SavedLocation` (ve `PrayerSchedule`) koordinatları **opsiyonel** yapıldı;
placeholder ASLA saklanmıyor. Geocode önce ilçe, sonra il ile denenir; ikisi de olmazsa
koordinat `nil` kalır. Vakitler etkilenmez — Diyanet yalnızca `diyanetDistrictID` kullanır.
`QiblaManager` konum izni varsa **tek seferlik gerçek GPS** ölçümüyle açıyı hesaplar
(kayıtlı koordinattan daha kesin); izin yoksa yalnızca DOĞRULANMIŞ kayıtlı koordinata
düşer; hiçbiri yoksa `bearingAvailable = false` olur ve iOS/watch ekranları yön çizmek
yerine konum izni ister. GPS ile aynı ilçe doğrulandığında eksik koordinat sessizce
doldurulur (Aladhan/lokal fallback tekrar çalışsın).
**Neden bu kadar sert:** Namaz uygulamasında yanlış kıble, sessizce yanlış çalışan ve
kullanıcının fark edemeyeceği bir hata. "Koordinatsız kalmak", "yanlış koordinat"tan iyidir.
**Geriye dönük uyumluluk:** 1.4 ve öncesinde yazılmış kayıtlarda alanlar dolu olduğu için
opsiyonele decode sorunsuz; simülatörde legacy plist'le doğrulandı (İstanbul → 152°,
bağımsız hesap 151.6°).

## 2026-08-24 — Konum sürüklenme uyarısı mesafe eşiği ister (25 km)
**Sorun:** `checkForLocationDrift` kararını yalnızca Diyanet ilçe ID'si değişti mi diye
veriyordu; GPS ise `kCLLocationAccuracyKilometer` (~1 km) ile çalışıyor. İlçe sınırına
yakın oturan kullanıcı **evindeyken** komşu ilçeye düşen bir ölçüm yüzünden "Konum değişti
mi?" uyarısı alabiliyordu. Ret hafızası tek bir ilçe ID'si tuttuğundan, ölçüm iki komşu
ilçe arasında salınıyorsa birini reddetmek diğerini susturmuyordu. (İstanbul,
`LocationOverrides` ilçeleri 9541'e bağladığı için korunuyordu; Ankara/İzmir/Bursa değil.)
**Karar:** İlçe değişikliğine ek olarak kayıtlı ve tespit edilen koordinat arasında
**≥ 25 km** şartı (`SekineApp.isMeaningfulMove`). Gerekçe: Türkiye enlemlerinde ~21 km
boylam farkı ≈ 1 dakika vakit farkı → altında vakitler pratikte aynı, sormaya değmez;
GPS gürültüsü (~1-3 km) çok altında kalır; şehirlerarası seyahat rahatça geçer.
Kayıtlı koordinat yoksa mesafe bilinemez → ilçe değişikliği tek sinyal olarak kalır.
**Doğrulama:** ~10 km hareket uyarı üretmiyor, Sakarya (~150 km) üretiyor (kontrol testli).

## 2026-08-23 — Şemalar project.yml'de TANIMLANIR (Xcode otomatik-şemasına güvenilmez)
**Sorun:** XcodeGen hiç `.xcscheme` dosyası üretmiyordu; şemalar Xcode tarafından
otomatik oluşturulup `xcuserdata`'da (kullanıcıya özel, gitignore'da) tutuluyordu. Bu
durum `xcodegen generate` sonrası bozulabiliyor: Xcode'un şema seçicisinde **"Sekine"
şeması kayboldu** (yalnızca SekineWatch/Complications/Widget görünüyordu) ve
`xcschememanagement.plist` yalnızca 3 şema içeriyordu — kullanıcı yanlışlıkla bir
extension'ı arşivlemek üzereydi. Aynı kök neden Xcode Cloud'da da görülmüştü: build
loglarındaki "Catalog app product and scheme metadata" adımı yalnızca Watch/
Complications/Widget buluyor, paket çözümlemesini `-scheme SekineWidget` ile yapıyordu;
bu yüzden `ci_post_clone.sh`'ta `-scheme` kullanmaktan vazgeçilmişti (bkz. 2026-08-20).
**Karar:** Dört şema da `project.yml`'deki `schemes:` bloğunda açıkça tanımlanır. XcodeGen
bunları `Sekine.xcodeproj/xcshareddata/xcschemes/` altına **paylaşılan** şema olarak yazar.
`Sekine` şeması `SekineTests`'i test hedefi olarak içerir (coverage açık).
**Neden bu yeterli:** `.xcscheme` dosyaları `Sekine.xcodeproj/` içinde olduğu için git'e
girmiyor, ama tek kaynak olan `project.yml` giriyor ve şemalar her `xcodegen generate`'te
(yerelde ve Xcode Cloud'un post-clone adımında) deterministik olarak yeniden üretiliyor.
Doğrulandı: `Sekine.xcodeproj` tamamen silinip sıfırdan üretildiğinde dört şema da mevcut.
**Elenen alternatif:** Otomatik şemalara güvenip bozulunca elle "Autocreate Schemes Now"
demek — her `xcodegen generate` sonrası tekrarlayan, sessizce yanlış hedefi arşivletebilen
bir tuzak; makine/kullanıcı değişince de taşınmıyor.

## 2026-08-20 — Xcode Cloud + XcodeGen: ci_scripts/ci_post_clone.sh zorunlu, push öncesi scripts/verify-xcode-cloud.sh
**Sorun:** `Sekine.xcodeproj/` bilinçli olarak gitignore'da (XcodeGen üretimi, kaynak
`project.yml`). Xcode Cloud repoyu clone'layıp doğrudan `Sekine.xcodeproj` arıyor → build 19
"Project Sekine.xcodeproj does not exist at the root of the repository" ile fail etti.
Düzeltilince (post-clone'da `xcodegen generate`), ikinci katman sorun çıktı: Xcode Cloud'un
CI ortamı `com.apple.dt.Xcode` defaults'ında `IDEPackageOnlyUseVersionsFromResolvedFile` ve
`IDEDisableAutomaticPackageResolution`'ı zorunlu kılıyor — bu, HER xcodebuild çağrısının
(bizim post-clone'daki dahil) önceden var olan bir `Package.resolved` istemesine sebep
oluyor; ama proje her seferinde SIFIRDAN üretildiğinden o dosya hiç var olamıyor (tavuk-yumurta).
**Karar:** `ci_scripts/ci_post_clone.sh` şu sırayla çalışır: (1) yukarıdaki iki `defaults`
anahtarını sil, (2) xcodegen kurulu değilse brew ile kur, (3) `xcodegen generate`,
(4) `xcodebuild -resolvePackageDependencies -project Sekine.xcodeproj` (scheme belirtmeye
gerek yok — xcodegen hiç `.xcscheme` dosyası yazmıyor, xcodebuild target'lardan örtük
scheme listesi çıkarıyor, `-scheme` verilirse CI'da bazı yollarda patlıyor).
**Tekrarını önleme:** `scripts/verify-xcode-cloud.sh` eklendi — `Sekine.xcodeproj`'u silip
gerçek `ci_post_clone.sh`'ı çalıştırıp `CODE_SIGNING_ALLOWED=NO` ile build alır (imzalama
yerel/CI'da farklı olduğundan archive değil build; App Groups/Time Sensitive Notifications
entitlement'ları yerel development profilinde yok). `project.yml` veya `ci_scripts/`
değişince push'tan ÖNCE bu script çalıştırılmalı — Xcode Cloud'un push→bekle→log-oku
döngüsü yerine 30 saniyede yerel doğrulama.
**Elenen alternatifler:** (a) `Sekine.xcodeproj`'u gitignore'dan çıkarıp commit etmek —
XcodeGen'in "tek kaynak project.yml" ilkesini bozar, iki dosya sürüklenme riski yaratır,
reddedildi. (b) `-onlyUsePackageVersionsFromResolvedFile NO` gibi xcodebuild flag'i geçmek
— bu flag argüman almayan bir "presence" anahtarı, `NO` değeri "Unknown build action 'NO'"
hatası veriyor; zaten mesele flag'in bizim geçtiğimiz bir şey değil, Xcode Cloud'un
defaults seviyesinde zorladığı bir ayar olması.

## 2026-08-01 — Vakit kaynağı: Aladhan method=13, kaynak-bağımsız mimari
**Karar:** v1, vakitleri Aladhan API `method=13` (Diyanet İşleri Başkanlığı) ile bir kez
indirip cihazda cache'ler. Veri katmanı `PrayerTimeProvider` protokolü ile soyutlandı.
**Neden:** Kimlik bilgisi/kayıt gerektirmez, stabil, çevrimdışı çalışmayı destekler,
gizlilik korunur (tek çağrı, tracking yok).
**Risk:** Aladhan bu metodu "(experimental)" olarak işaretliyor; Diyanet'in resmi
yayınlanan tablosundan özellikle İmsak/Fajr'da birkaç dakika sapabilir. Türk kullanıcı
bunu fark eder → düşük yıldız riski.
**Azaltma:** Submit öncesi İstanbul/Ankara/İzmir için Diyanet resmi vakitleriyle
karşılaştırma ZORUNLU. Sistematik sapma varsa aynı protokolü uygulayan Diyanet resmi
(awqatsalah) sağlayıcısı eklenecek — uygulamanın geri kalanı değişmez.
**Elenen alternatifler:** (a) Tamamen lokal hesap (adhan-swift) → daha da sapar, sadece
fallback yapıldı. (b) vakit.vercel.app Diyanet API'si → endpoint'leri kapalı/değişmiş.

## 2026-08-01 — Native SwiftUI (cross-platform değil)
**Karar:** iOS native SwiftUI; Android Faz 2'de ayrı Kotlin.
**Neden:** Uygulamanın çekirdek değeri bildirim güvenilirliği + ses kontrolü — iOS'un en
kısıtlı alanı. Native, UNUserNotificationCenter/BGTask üzerinde maksimum kontrol verir.
Cross-platform framework tam bu eksende zayıf.
**Elenen:** Expo/React Native (tek kod tabanı avantajı, ama kritik eksende kontrol kaybı).

## 2026-08-01 — v1 ücretsiz + reklamsız; abonelik v1.1
**Karar:** v1'de IAP yok; `PremiumGate` her zaman false. Tam ezan (peşpeşe bildirim)
aboneliği v1.1.
**Neden:** En hızlı store yolu (StoreKit/vergi/IAP review karmaşası v1'i geciktirmesin).
Reklamsızlık + gizlilik zaten pazarda öne çıkarır (rakiplerin en büyük şikayeti reklam).

## 2026-08-01 — Bildirim güvenilirliği: çok katmanlı rolling scheduler
**Karar:** iOS 64-bildirim sınırının altında (60) kayan pencere; app açılışı + BGAppRefresh
+ willPresent üç tetikleyiciyle tazelenir; veri cache'ten okunur (network gerektirmez).
**Neden:** Rakiplerin 1 numaralı şikayeti "bildirimler bir süre sonra duruyor". Tek
tetikleyici (ör. sadece BGRefresh) iOS'ta garanti değil; katmanlı yaklaşım güvenilir kılar.

## 2026-08-01 — Ses: orijinal chime; tam ezan yok (v1)
**Karar:** Telifsiz orijinal `chime.caf` (2.5 sn) üretildi; "Kısa Ezan" seçeneği v1'den
çıkarıldı.
**Neden:** Kaliteli/telifsiz tam ezan sesi v1'de sağlanamaz; sahte/düşük kalite ses
yerine dürüst kısa bildirim. Tam ezan v1.1 premium.
