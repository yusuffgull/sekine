# Kararlar (ADR-lite)

> Yeni girdi en üste. Geçmiş girdiler geriye dönük düzenlenmez.

## 2026-09-24 — Yıllık abonelik eklendi (Faz 1, T3 — para akışı)

**Karar:** `com.sekineapp.sekine.premium.yearly` (₺149.99, 7 gün ücretsiz deneme) ömürlük
premium'un yanına eklendi, ikisi birlikte sunuluyor (yıllık önerilen/birincil buton).
Kapsam: büyüme planının Faz 1'i (bkz. `docs/handoff.md`,
`~/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`).

**Uygulama:** `Store.entitlementProductIDs` (lifetime + yearly) tek doğruluk kaynağı;
`applyVerifiedTransactionInfo`, `entitlementsScanProvider`, `loadProducts` hepsi bunu
kullanıyor — yeni bir entitlement veren ürün eklenmek istenirse tek satır. Mevcut
generation-korumalı race-condition mimarisine (6 tur review'dan geçmiş, bkz. 2026-09-08
girdisi) DOKUNULMADI — yalnızca "hangi productID entitlement verir" sorgusu genişletildi.

**Bilinçli kabul edilen sınır:** Abonelik sessizce süresi dolduğunda (kullanıcı
yenilemedi) bu yalnızca bir sonraki app-launch/restore taramasında fark edilir, anlık
değil — çünkü StoreKit süre dolumunda `Transaction.updates` event'i GÖNDERMEZ, sadece
`currentEntitlements`'tan düşer. Yenileme ise anında yakalanır (yeni transaction).
Gerekirse `expirationDate` bazlı arka plan kontrolüyle sıkılaştırılabilir — v1 için
gereksiz karmaşıklık.

**Doğrulama:** 72 birim testi (2 yeni: yıllık satın alma entitlement veriyor, bağış
entitlement VERMİYOR) yeşil, iOS simülatör derlemesi başarılı. Gerçek StoreKit
satın alma/abonelik yenileme/iptal akışı bu ortamda test edilemiyor (bkz.
`StoreEntitlementTests.swift` başlık yorumu) — gerçek cihaz sandbox testi hâlâ gerekiyor
(1.7 ile birlikte, submit öncesi).

**Elenen alternatif:** Yalnızca aboneliğe geçip ömürlüğü kaldırmak — kullanıcı bunu
onaylı planda reddetti ("Ömürlük + yıllık abonelik"), "abonelik zorunluluğu yok" mevcut
konumlandırmasıyla çelişir.
## 2026-09-24 — Yurtdışı konum desteği + kritik saat dilimi düzeltmesi (Faz 2)

**Karar:** `DiyanetProvider`, Diyanet vakit ID'si seçilen HER konum için sabit
`Europe/Istanbul` varsayıyordu — Türkiye dışında bu SESSİZCE yanlış vakit demekti
(bkz. memory: dini veride doğruluk, dar kapsam yok tam düzeltme). Aynı `ezanvakti
.emushaf.net` servisi zaten 105+ ülkeyi kapsıyor (Almanya, Hollanda, ABD dahil) —
ayrı bir veri kaynağı gerekmedi, yalnızca (1) ülke seçimi ve (2) doğru saat dilimi
eklendi.

**Saat dilimi düzeltmesi (kritik, ölçülüp doğrulandı):** API'nin
`GreenwichOrtalamaZamani` alanı yurt dışı ilçelerde GÖZLEMSEL OLARAK hep Türkiye'nin
kendi ofsetini döndürüyor (Berlin için de "+3" veriyor — yanlış). Ama aynı yanıttaki
`MiladiTarihUzunIso8601` alanının sonundaki `±HH:MM` kısmı (ör. Berlin Eylül'de
`+02:00`, Türkiye `+03:00`) GÜNLÜK ve DOĞRU — hedef ülkenin kendi yaz/kış saati
kuralına göre hesaplanmış. `curl` ile canlı doğrulandı (Berlin ilçe ID 11002 →
`+02:00`, Türkiye → `+03:00`, aynı gün). Artık her günün MUTLAK `Date`'i kendi
GERÇEK ofsetinden hesaplanıyor; ofset ayrıştırılamazsa (alan yok/beklenmedik biçim)
`Europe/Istanbul`'a düşülüyor (geriye dönük uyumlu, asla crash/veri kaybı yok).

**Bilinen dar sınır (kabul edildi):** `PrayerSchedule.timeZoneIdentifier` tek bir
alan (şema değişikliği gerektirmeden) — ilk günün ofseti temsilci alınıyor. DST
uygulayan bir ülkede geçiş günü tam kayan pencerenin ortasına denk gelirse (yılda
en fazla 2 gün), `day(containing:)` gün sınırını ~1 saatlik dar bir pencerede yanlış
kovaya düşürebilir. Her günün KENDİ mutlak `Date`'i yine de doğru hesaplanmış
durumda — yalnızca "hangi gün kovası" sınıflandırması dar bir pencerede kayabilir.
Şema geniş çaplı değişmeden (her `PrayerDay`'e kendi tz'sini eklemek) tam çözülemez;
v1 için kabul edilebilir.

**`LocalCalculationProvider`'da da aynı sınıf hata bulundu ve düzeltildi:** ağ/GPS
yokken devreye giren yerel (adhan-swift) hesaplama da gün sınırını sabit
`Europe/Istanbul` ile çiziyordu. `TimeZone.current`'a çevrildi — bu fallback yalnızca
kullanıcının FİZİKSEL olarak bulunduğu an devreye girdiği için cihazın kendi saat
dilimi en iyi yaklaşık sinyal. Hesaplama METODU (`CalculationMethod.turkey`,
Diyanet'e en yakın fıkıh parametreleri) bilinçli olarak konumdan bağımsız kalmaya
devam ediyor.

**Ülke seçimi:** `DiyanetDirectory`'ye `countries()` + `cities(countryID:)` +
`country(forISOCode:)` eklendi. GPS akışı (`LocationManager.resolveAndMatchDiyanet
Location`) artık önce GPS'in verdiği ülkeyi (`CLPlacemark.isoCountryCode` →
`Locale.localizedString(forRegionCode:)` → Diyanet'in İngilizce ülke adıyla
eşleştirme) bulup O ÜLKE içinde arıyor — önceden yalnızca Türkiye il listesinde
aranıyordu, yurt dışındaki kullanıcı için her zaman "eşleşme yok" sonucu veriyordu
(rakip yorum analizinde de "yurtdışı konum kabul etmiyor" sık şikayetti). Manuel
arama (`LocationSearchSheet`) da bir ülke seçici kazandı, varsayılan Türkiye.

**Bilinçli kapsam dışı bırakılan (ayrı bir tur gerektirir):** Onboarding ve
watchOS'un kendi `LocationSearchSheet`-benzeri akışları (`OnboardingView`,
`WatchOnboardingView`) hâlâ yalnızca Türkiye arıyor (`directory.cities()`
parametresiz çağrılıyor, varsayılan Türkiye'ye düşüyor — davranış DEĞİŞMEDİ, kırılma
yok). GPS akışı zaten otomatik ülke tespit ediyor; bu iki ekrandaki MANUEL arama
akışına ülke seçici eklemek ayrı, düşük öncelikli bir iyileştirme (çoğu kullanıcı
GPS kullanıyor).

**Doğrulama:** yeni birim testleri (Berlin ofsetinin Türkiye'ye sessizce
düşmediğini, offset ayrıştırmanın +/-/malformed durumlarını doğrulayan) dahil test
suite'i yeşil, iOS simülatör derlemesi (Watch hedefi dahil, tek `Sekine` şeması)
başarılı. Gerçek cihazda Almanya/Hollanda için Diyanet web sitesiyle birebir
karşılaştırma HENÜZ yapılmadı — kullanıcı aksiyonu.
## 2026-09-24 — Kaza namazı takibi eklendi (Faz 3, ilk parça)

**Karar:** `KazaTracker` (yeni, `Sekine/Core/Kaza/`) — 5 vakit için "kalan borç"
sayacı + tamamlama günlüğünden türetilen seri (streak). `Store.swift`/`PremiumGate`
ile aynı desen: `AppSettings`'e eklenmedi, kendi başına test edilebilir ayrı bir
`ObservableObject`. Tamamen yerel (App Group UserDefaults), hiçbir veri cihaz
dışına çıkmaz.

**Kapsam kararı:** Ücretsiz = sayaçlar + seri. Premium = geçmiş istatistik (son
7/30 gün ve toplam tamamlama sayısı) — plan dosyasındaki "ücretsiz sayaç, premium
istatistik" ayrımına birebir uyuyor.

**Seri (streak) mantığı:** Bugün henüz kayıt yoksa ama dün vardıysa seri
SIFIRLANMAZ (gün bitmeden cezalandırıcı olur) — dünden geriye doğru sayılır. Saf,
`Date`'e bağımlı olmayan `computeStreak(from:calendar:asOf:)` fonksiyonu ile test
edildi (boş log, ardışık günler, aynı gün mükerrer kayıt, gün atlama sonrası
sıfırlanma — hepsi ayrı test).

**Doğrulama:** 11 yeni birim testi yeşil, `xcrun simctl` ile simülatörde GERÇEKTEN
çalıştırılıp ekran görüntüsü alındı (sayaçlar, "Kıldım" butonunun 0 borçta devre
dışı kalması, premium istatistik bölümü doğrulandı) — yalnızca statik derleme
değil. Etkileşimli dokunma bu ortamda otomatikleştirilemediği için (headless,
GUI/AppleScript erişimi yok) doğrudan `KazaView`'i açan geçici bir DEBUG launch
argümanı (`-uiTestShowKaza`) eklendi — mevcut `-uiTestShowPaywall` ile aynı desen,
gelecekte mağaza görseli üretiminde de işe yarayabilir, kaldırılmadı.

**Kapsam dışı (ayrı bir tur):** çok aylık imsakiye, Kur'an+meal, Ramazan modu, AI
ezan denemesi, In-App Events — plan dosyasının Faz 3 bölümünde sırayla.

**Yan not — bilinen flaky test:** Tam suite çalıştırılırken
`RollingSchedulerTests.testMarkExpiredRealConcurrencyWithJobCompletionNeverLosesWorkOrLeaksToFutureJobs`
bir kez başarısız oldu (Kaza değişikliğiyle ilgisiz — RollingScheduler bu dalda hiç
değişmedi). İzole çalıştırıldığında (0.011sn) ve tam suite ikinci çalıştırmada
(83/83) sorunsuz geçti — gerçek eşzamanlılık testi olduğu için ortam yüküne göre
ara sıra kırılgan olabileceği zaten 2026-09-08 girdisinde belgelenmişti, yeni bir
regresyon değil.
## 2026-09-27 — Kullanıcı yönlendirmesi: çok-ay imsakiye, Kur'an, AI ezan (SONRAKİ OTURUM BURADAN DEVAM)

**Çok aylık imsakiye — engel veri boyutu DEĞİLDİ.** Engel kaynağın API sözleşmesi: `ezanvakti
.emushaf.net` her zaman "bugünden itibaren 32 gün" döndürür, tarih aralığı parametresi yok
(bu yüzden ileri aylar bu kaynaktan alınamaz). Alternatifler: (a) Diyanet resmî Awqat Salah API
(aralık destekler; hesap/kimlik bilgisi + kota günde ~5/ayda ~10 istek/konum → uygulamaya
gömülemez, proxy/cache gerekir — kota ve kimlik detayı DOĞRULANMADI); (b) Aladhan `method=13`
(anahtarsız, yıllık `calendar` endpoint'i, hesaplama-tabanlı).

**Kullanıcı kararı (2026-09-27): "telefonda büyük veri tutmaya gerek yok; çevrimdışıyken mevcut
kısıtlı veri, çevrimiçiyken internetten çekip gösterilsin; en azından yıllık gösterilsin."**
Hedef mimari: yakın 32 gün Diyanet-birebir (mevcut, çevrimdışı çalışır); ötesi çevrimiçiyken
çekilip **"hesaplanan/yaklaşık" etiketiyle** gösterilir (çevrimdışı ve yoksa mevcut davranış).
Bu, önceki "çevrimdışı+gizli" vaadini bozmaz (yalnızca koordinat gider; Aladhan zaten yedek
sağlayıcı) ama "Diyanet birebir" iddiasını ileri aylar için etiketle sınırlar.

**Ölçüm (2026-09-27, İstanbul/9541, Diyanet 23.09–24.10.2026 32 gün vs Aladhan method=13):**
İmsak +0..+1 dk, Güneş +0..+1, Öğle −1..0, İkindi 0..+1, **Akşam −1..−2 dk (ort −1.2), Yatsı
−1..−2**. Yani Aladhan iftarı Diyanet'ten 1–2 dk ERKEN veriyor → oruç açmak için güvensiz yön.
**Tasarım kuralı:** yaklaşık veride iftar (akşam) için güvenli pay ekle (en az +2 dk) VEYA
Ramazan'da iftar/sahur için yaklaşık veri hiç gösterme/uyar; Ramazan sayacı yalnızca
Diyanet-birebir pencereden çalışmaya devam etsin. Tek şehir/tek mevsim ölçümü — uygulamadan
önce birkaç şehir/farklı mevsim (ve yurt dışı) ile genişlet. Kaynak seçimi kararı (Aladhan vs
Awqat Salah+proxy) sonraki oturumda; uygulama: `PrayerTimeStore` yıllık yaklaşık plan +
MonthlyView'de "yaklaşık" rozeti + Ramazan güvenlik payı + birim testleri.

**Kur'an+meal — TARTIŞMA AÇIK (kod yok).** Engel lisans (Tanzil Türkçe mealleri "ticari olmayan").
Konuşulacak seçenekler (hepsinde iddialar birincil kaynaktan DOĞRULANACAK): (1) Uygulama içinden
resmî Diyanet Kur'an sitesine/Quran.com'a bağlantı (SFSafariViewController) — lisans riski yok,
en hızlı, sevilen özelliğin bir kısmını karşılar; (2) Yalnızca Arapça metin gömmek — Tanzil Arapça
metin lisansını (CC-BY olduğu bilgisi doğrulanmadı) birincil kaynaktan oku; (3) Diyanet
İşleri/Diyanet Vakfı'ndan yazılı ticari kullanım izni; (4) gerçekten kamu malı bir Elmalılı
sayısallaştırması bul + provenance belgele (sadeleştirilmiş baskılar telifli olabilir). Öneri:
önce (1), paralelde (3) için yazışma; (2)/(4) lisans netleşince.

**AI ezan — kullanıcı kararı: önce ElevenLabs ÜCRETSİZ hakkıyla dene; olmazsa işimizi görecek kadar
ödeme yaparak seslendirt.** Uyarılar: (a) hesap açma/anahtar kullanıcıda (ajan hesap açamaz);
anahtar env değişkeniyle verilmeli, repoya/loga yazılmamalı; (b) ElevenLabs ücretsiz planın
ticari kullanım/atıf koşulları DOĞRULANMADI — ücretsiz üretim yalnızca dinleme testi sayılmalı,
ticari uygulamaya gömmeden önce ücretli planın ticari lisansı ve içerik sahipliği koşulları
okunmalı; (c) TTS konuşma sentezi makamlı ezan okumaz — müzik/şarkı üreten modeller denenmeli,
kalite garantisi yok; (d) dini hassasiyet: plandaki 3–5 kişilik dinleyici paneli kapısı geçerli,
oybirliği yoksa yol bırakılır; plan B yerel müezzine ücretli kayıt + yazılı tam hak.

## 2026-09-26 — Sertleştirme: RollingScheduler P1/P2 + StoreKit #4/#6 kapatıldı (`feat/polish-and-hardening`)

**Kök neden buldu:** Tam suite'i `-test-iterations 15` ile döngüye alınca
`testMarkExpiredRealConcurrency…` ~%13 oranında düştü — "flaky test" sanılan şey 2026-09-08'de
kayda geçen **RollingScheduler P2 riskinin gerçek belirtisiydi**: kuyrukta bekleyen işi expire
etmek `RescheduleResult(requested:0, deferred:1)` döndürüyordu, `requested == added+deferred+failed`
değişmezini bozuyordu. Düzeltme: `requested:1, deferred:1` (hiç başlamamış tek iş birimi).

**RollingScheduler P1:** 60sn'den uzun süren, expire edilmiş AKTİF işin işareti başka bir işin
`markExpired` çağrısındaki TTL süpürmesiyle siliniyordu → iş expire olmamış gibi devam ederdi.
Düzeltme: `activeTokens` kümesi; süpürme aktif işlerin işaretine dokunmaz. TTL artık enjekte
edilebilir (`init(expiredTokenTTL:)`). Mutasyon kontrolü: düzeltme geçici geri alınınca yeni test
düşüyor (iş expire edilmiş halde 50/50 bildirim ekledi) — test gerçekten hatayı yakalıyor.

**StoreKit #4 (asılı restore):** `restore()` artık 45sn zaman aşımına sahip (test seam'i
`restoreTimeout`); aşımda `.networkError`, `isRestoring` false, Store tıkanmaz, sonraki restore
yeni task başlatır. Yapısal `TaskGroup` KULLANILMADI (kooperatif olmayan iş grubu bekletir);
ilk biten kazanır (`OnceGate`). **#6:** doğrulanamayan `Transaction.updates` olayı, sahip
DEĞİLKEN durumu `.indeterminate` yapar; `.owned`'ı asla bozmaz, bağış ürünlerine dokunmaz.
**Kalan bilinen StoreKit riskleri (#1, #2, #3, #5):** kozmetik/UX düzeyi, dokunulmadı.

**Diğer:** watchOS onboarding'e ülke seçici + GPS'te ülke tespiti; `DiyanetDirectory` tek
örnek (environment); Live Activity için Ayarlar anahtarı. Doğrulama: tam suite 10 tur × 114 test
= 1140 çalıştırma, 0 hata. Not: paylaşımlı simülatörde başka bir projenin testleri koşarken
"Mach error -308 server died" alındı; bağımsız cihaz (iPhone 17 Pro) kullanıldı.

## 2026-09-24 — Ramazan iftar Live Activity (`feat/live-activity`, fasting-tracker üstüne)

**Karar:** Oruç sürerken (imsak→akşam) kilit ekranı/Dynamic Island'da iftar geri sayımı.
`IftarActivityAttributes` + `IftarLockScreenView` (Shared, yalnızca iOS), widget uzantısında
`IftarLiveActivity`, uygulamada `IftarLiveActivityManager` (karar `RamadanInfo`'dan: hicri veri
yoksa/Ramazan değilse başlatmaz; iftar sonrası bitirir). Geri sayım `Text(timerInterval:)`
ile SİSTEM çizer → uygulama çalışmasa da akar, push/güncelleme yok. Tetik: uygulama öne
gelince ve plan yüklenince. `NSSupportsLiveActivities` eklendi (`project.yml` değişti →
`verify-xcode-cloud.sh` yeşil). Kullanıcı iOS Ayarlar'dan Live Activity'yi kapatırsa sessizce
hiçbir şey yapılmaz; uygulama içi ayrı anahtar eklenmedi (ayrı tur olabilir).

**Doğrulama ve SINIR (dürüst):** (1) karar mantığı 4 testle; (2) `ImageRenderer` ile
yerleşim gözle kontrol edildi — ilk sürümde geri sayım ve başlık KESİLİYORDU, düzeltildi;
(3) simülatörde `-uiTestRamadan` ile `Activity.request` GERÇEKTEN başarılı oldu (log:
id + iftar 19:06). **Görülemeyen:** sistemin kilit ekranı/Dynamic Island çerçevesi (headless
simülatör ekran görüntüsünde adacık yok) — Dynamic Island düzeni cihazda gözle kontrol
edilmeli. Not: Watch/komplikasyon hedefleri `Shared`'i derlediği için ActivityKit kodu
`#if os(iOS)` ile sarıldı (tam derleme yeşil).

## 2026-09-24 — Oruç günü takibi (Faz 3, `feat/fasting-tracker`, integration üstüne)

**Karar:** `FastingTracker` (yerel, hiçbir yere gönderilmez) + Ramazan kartında "Bugün oruç
tuttum" işareti ve "Bu Ramazan: N / gün". Günler konumun saat diliminde `yyyy-MM-dd`
anahtarıyla saklanır. Ramazan ilerlemesi hicri yıl ayrıştırılmadan hesaplanır: başlangıç =
bugün − (gün−1) (gün numarası Diyanet'in hicri verisinden, bkz. `RamadanInfo`) → önceki
aylarda (Şaban) işaretlenen günler sayılmaz (test). Ücretsiz (Ramazan kitlesini büyütür,
premium duvarı yok). Doğrulama: 5 yeni test (toplam 104 yeşil), simülatörde `-uiTestRamadan`
ile kart görsel doğrulandı (18:16'da iftara 49 dk, "0 / 12 gün"). Dokunma etkileşimi bu
ortamda otomatikleştirilemedi; mantık testli. `RamadanCard` artık `FastingTracker`
environment nesnesi ister (SekineApp'te enjekte edildi).

## 2026-09-24 — Kur'an+meal ENGELLENDİ: Tanzil Türkçe meal lisansı ticari kullanıma kapalı (Faz 3)

**Bulgu (tanzil.net/trans, canlı kontrol):** Tanzil'deki 10 Türkçe meal (Diyanet İşleri,
Diyanet Vakfı, Elmalılı Hamdi Yazır `tr.yazir`, Ali Bulaç, Süleyman Ateş, Öztürk, vb.)
için site açıkça "translations ... are for non-commercial purposes only; other uses
require permission from the translator or publisher" diyor. Sekine ticari (Premium +
bağış) → bu dosyaları uygulamaya gömmek lisans ihlali riski. `tanzil_terms_of_use`
sayfası yüklenmedi; Arapça metin lisansı (CC-BY olduğu bilgisi) doğrulanamadı, varsayılmıyor.

**Karar:** Kur'an+meal KODLANMADI. Elmalılı'nın orijinali kamu malı olsa da Tanzil'deki
`tr.yazir` belirli bir sayısallaştırılmış/sadeleştirilmiş baskı; hukuki durumu kullanıcı
ya da hukuk danışmanı netleştirmeli. Seçenekler (kullanıcı kararı): (a) yalnızca Arapça
metin — önce Tanzil'in Arapça metin lisansını birincil kaynaktan doğrula; (b) Diyanet
Vakfı'ndan yazılı ticari izin; (c) gerçekten kamu malı bir Elmalılı sayısallaştırması
bulup provenance'ını belgele; (d) Kur'an'ı kapsam dışı bırak (rakip yorumlarında sevilen
özellik ama ihlal riskine değmez).

## 2026-09-24 — Ramazan modu (sahur/iftar sayacı) + çok-ay imsakiye KASITLI ATLANDI (Faz 3)

**Karar:** `RamadanInfo` (Shared, saf/test edilmiş) + `RamadanCard` (Ana ekran). Ramazan'ı
tarih tablosundan DEĞİL Diyanet'in kendi hicri verisinden tanır (`hicriMonth == 9`) —
ru'yet ile ay başı kayarsa otomatik doğru kalır, elle girilmiş tarih yok. Hicri veri
yalnızca Diyanet kaynağında dolu; Aladhan/yerel fallback'te (nil) mod SESSİZCE kapalı
kalır, asla tahmin edilmez (test: `testMissingHicriDataReturnsNilNeverGuesses`).
Faz: gündüz → iftara (akşam) geri sayım; gece/imsak öncesi → imsağa; iftar sonrası →
ERTESİ günün imsağı (ertesi gün planda yoksa yanlış hedef göstermek yerine nil).
Pencere içinde Ramazan'a ≤~30 gün varsa "Ramazan'a N gün kaldı" bandı.

**Çok aylık imsakiye bilinçli olarak YAPILMADI:** 2026-09-08'de kullanıcı bunu açıkça
ertelemişti ("dokunma, mevcut pencereyi koru"; kaynak API sabit 32 gün veriyor, çözümler
"çevrimdışı/gizli" ya da "Diyanet birebir" vaadini bozuyor). Faz 3 planında bunu "şart"
diye yazmam yanlıştı: Ramazan başında uygulama açılınca 32 günlük pencere ayın tamamını
zaten kapsar; eksik olan yalnızca Ramazan ÖNCESİ tam ay önizlemesi (yukarıdaki "N gün
kaldı" bandı bunu kısmen karşılar). Karar kullanıcıya ait; yeniden açılırsa seçenek:
`LocalCalculationProvider` ile ileri aylar "yaklaşık" etiketiyle — doğruluk vaadi
tradeoff'u nedeniyle ayrıca onay gerekir.

**Kapsam dışı (ayrı tur):** iftar Live Activity (ActivityKit hedefi + entitlement, cihazsız
doğrulanamaz), oruç günü takibi, paylaşılabilir imsakiye görseli.

**Doğrulama:** 9 yeni birim testi; simülatörde `-uiTestRamadan` (DEBUG) ile gerçekten
çalıştırıldı — 13:59'da iftar 19:06 → "5 sa 06 dk" (aritmetik doğru).
## 2026-09-24 — Paylaşılabilir vakit kartı + AI ezan denemesi ENGELLİ (Faz 1/3 büyüme)

**Paylaşım kartı:** Ana ekrana "Bugünün vakitlerini paylaş" (ücretsiz). `ShareCardView`
1080×1350 sabit, tema/koyu moddan bağımsız; alt kısımda HER ZAMAN "Sekine · Reklamsız,
takipsiz namaz vakitleri" + App Store adı (WhatsApp aile gruplarında organik büyüme).
Saatler konumun kendi saat diliminde biçimlenir (yurt dışında cihaz saati değil).
Ramazan'da (hicriMonth==9) imsak/akşam "sahur sonu/iftar" adıyla vurgulanır. Paylaşım
metnine App Store linki eklenir (görüntüdeki yazı tıklanamaz). Doğrulama: DEBUG
`-uiTestExportShareCard` ile gerçek PNG diske yazılıp gözle kontrol edildi (1080×1350),
2 birim testi. Bağımsız dal: `RamadanInfo`'ya bağımlı değil (yerel sabit; birleşince
tek sabite indirilebilir).

**AI ezan denemesi YAPILAMADI (engelli):** (1) youtube-miner `docs/decisions.md`'ye göre
ElevenLabs'e hiç kaydolunmamış — hesap/anahtar yok, hesap açma/ödeme ajan tarafından
yapılamaz; (2) mevcut ses altyapısı (edge-TTS / yerel VoiceStudio) KONUŞMA sentezi —
makamlı ezan okuyamaz; (3) plandaki dinleyici paneli kapısı zaten insan onayı ister.
Öneri değişmedi: plan B (yerel müezzine ücretli kayıt + yazılı tam kullanım hakkı).

## 2026-09-23 — Büyüme/gelir planı: ürün değil dağıtım sorunu; ASO ilk faz

**Karar:** ASC Analytics (24 Haz–21 Eyl 2026, 90 gün) ve 9 rakip uygulamanın 327
yorumu incelendi. Sonuç: Sekine'nin ürün kalitesi sorun değil (5.0★, D35 ödeme
oranı %5.26 — kategori medyanından iyi), asıl darboğaz görünürlük (90 günde 39
indirme, dönüşüm %0.93 — medyan %1.62) ve puan sayısı (3 değerlendirme). Bu yüzden
ilk faz kod değil ASO: keywords yenilendi (App Name'de zaten geçen `ezan,namaz,vakit`
tekrarı ve düşük hacimli `sabah/öğle/ikindi/akşam/yatsı` çıkarıldı, yerine
`ramazan,iftar,sahur,kuran,zikirmatik,tesbih` eklendi), Promotional Text eklendi,
ekran görüntüsü sırası değişti (onboarding yerine gerçek ana ekran 1. sıraya alındı).
Detay ve tam yol haritası (Ekim: yıllık abonelik, Kasım: yurtdışı desteği + timezone
düzeltmesi, Aralık-Ocak: Ramazan modu + Kur'an + kaza takibi):
`/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`.

**Rakip analizinden çıkan #1 bulgu:** 96 adet 1-2★ yorumun ezici çoğunluğu reklam
şikayeti (uygunsuz reklam — flört/kumar/+18/kripto — ve açılışta tam ekran reklam).
Sekine'nin reklamsız olması rakiplere karşı en güçlü fark; mağaza metni ve ilk ekran
görüntüsü artık bunu doğrudan söylüyor.

**Hedef gerçekçiliği:** Kullanıcı hedefi (1 yılda App Store + YouTube'dan 3K$/ay
pasif gelir) Sekine tek başına karşılanamaz — bunun için ayda ~30-50K indirme
gerekir, mevcut trafik bunun çok altında. Gerçekçi yıl-1 aralığı Sekine için
150-500$/ay + Ramazan (8 Şub 2027) sıçraması. Kalan hedef portföyden (diğer 3
uygulama + YouTube kanalları) gelmeli; bu yüzden burada kurulan ASO/paywall/event
şablonu portföy geneline uygulanabilir şekilde belgelenecek.

**Elenen alternatif:** Doğrudan yeni özellik geliştirmeye başlamak (kullanıcının
ilk isteği). Veri, özellik eksikliğinin değil dağıtımın darboğaz olduğunu
gösterdiği için reddedildi — yeni özellik eklemek mevcut ~39 indirimlik trafiği
büyütmez.

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
