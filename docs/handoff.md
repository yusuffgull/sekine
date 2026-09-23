# Handoff

## CURRENT TASK — Büyüme/gelir planı, Faz 0 canlı + Faz 1/2 kod tarafı bitti
**23-24 Eyl 2026:** ASC Analytics + 9 rakip uygulamanın 327 yorumu incelendi, 1 yıllık
yol haritası çıkarıldı: `/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`
(kullanıcı onayladı). Gerekçe özeti: `docs/decisions.md` (2026-09-23).

**Faz 0 (ASO refresh) — tamamlandı, `main`'e merge edildi VE ASC'ye canlı işlendi:**
- Keywords, Promotional Text, açıklama gerekçesi güncellendi (`docs/store-submission.md`).
- Ekran görüntüsü sırası değişti: `1-home, 2-onboarding, 3-qibla, 4-monthly, 5-settings`.
  `scripts/generate-store-screenshots.sh` ile yeniden üretildi.
- Daha önce hiç commit edilmemiş ekran görüntüsü üretim altyapısı commit edildi.
- **ASC canlı 1.6 sürümünde Promotional Text güncellendi** (Chrome ile, elle onaylı).
- **ASC'de "1.7 Prepare for Submission" taslağı açıldı**, yeni keywords/promo
  text/description/what's-new/5 ekran görüntüsü girildi ve kaydedildi — **submit
  EDİLMEDİ**, sandbox satın alma testi bekliyor (kasıtlı, bkz. NEXT).

**Faz 1 (yıllık abonelik) — kod tarafı bitti, `feat/yearly-subscription` branch'i
(main'e merge EDİLMEDİ):**
- `com.sekineapp.sekine.premium.yearly` eklendi (₺149.99, 7 gün deneme).
  `Store.entitlementProductIDs` (lifetime+yearly) tek doğruluk kaynağı.
- `PaywallView`: yıllık (önerilen) + ömürlük yan yana, App Review'ın istediği otomatik
  yenileme açıklaması eklendi.
- NATASHA (T3 güvenlik review) temiz raporu verdi; tek düşük-önem bulgu (fiyat/deneme
  süresi metnini tek cümlede birleştirme) düzeltildi.
- Gerekçe: `docs/decisions.md` (2026-09-24, bu branch'in kendi commit'lerinde).

**Faz 2 (yurtdışı konum) — kod tarafı bitti, `feat/international-locations` branch'i
(main'e merge EDİLMEDİ, henüz commit edilmedi — bkz. NEXT):**
- **Kritik bug düzeltildi:** `DiyanetProvider` her konum için sabit `Europe/Istanbul`
  varsayıyordu — yurt dışı bir ilçe seçilse bile vakitler Türkiye saatiyle hesaplanıyordu
  (sessizce, kullanıcı uyarısız). Artık her günün GERÇEK ofseti Diyanet API'sinin kendi
  `MiladiTarihUzunIso8601` alanından okunuyor (curl ile Berlin +02:00 / Türkiye +03:00
  olarak doğrulandı — API'nin `GreenwichOrtalamaZamani` alanı bunun aksine yanlış).
  Aynı sınıf hata `LocalCalculationProvider`'da (ağsız fallback) da vardı, düzeltildi.
- Diyanet servisi zaten 105+ ülkeyi kapsıyor — `DiyanetDirectory`'ye `countries()` +
  `cities(countryID:)` + `country(forISOCode:)` eklendi.
- GPS akışı artık önce ülkeyi otomatik tespit edip o ülke içinde arıyor (önceden
  yalnızca Türkiye'de arayıp yurt dışı kullanıcı için hep "eşleşme yok" veriyordu —
  rakip yorumlarında da sık şikayetti).
- Manuel arama (`LocationSearchSheet`) bir ülke seçici kazandı, varsayılan Türkiye.
- Bilinçli kapsam dışı: Onboarding/watchOS'un kendi arama akışları hâlâ yalnızca
  Türkiye (GPS zaten otomatik ülke tespit ediyor, bu ekranlar ayrı bir tur).
- Yeni birim testleri (offset ayrıştırma + Türkiye'ye sessizce düşmediğinin kanıtı)
  dahil tüm test suite'i yeşil, Watch hedefi dahil tam derleme başarılı.
- Gerekçe + bilinen dar sınır: `docs/decisions.md` (2026-09-24).
- **Not (oturum içi kaza):** bu değişiklikler bir `git checkout main -- .` yanlışlığıyla
  bir kez working tree'den silindi (commit edilmemiş hâldeyken), aynı içerikle yeniden
  uygulandı. Faz 1'in kendi branch'i bu kazadan ETKİLENMEDİ (zaten commit'liydi).

**Henüz yapılmadı:**
1. Kullanıcı: `feat/yearly-subscription` ve `feat/international-locations`'ı incele,
   `main`'e merge et. **Faz 2 branch'i henüz commit edilmedi** — bir sonraki oturum
   önce `git status`/`git diff` ile çalışma alanını kontrol etmeli.
2. Kullanıcı: ASC'de yıllık abonelik ÜRÜNÜNÜ oluştur (kod tarafı hazır ama ASC'de ürün
   henüz yok — `loadProducts()` bulamadığı sürece yalnızca ömürlük görünür, sessizce
   bozulmaz).
3. Kullanıcı: gerçek cihazda hem ömürlük hem yıllık için sandbox satın alma/restore testi.
4. Kullanıcı: gerçek cihazda Almanya/Hollanda gibi bir konum için vakitleri Diyanet
   web sitesiyle birebir karşılaştır.
5. Kullanıcı: 1.7'yi (yıllık abonelik + yurtdışı desteği dahil bir build ile) submit et.
6. ASC'de: keywords/promo/description, Featuring nomination, Search Ads (10-30$/ay).
7. ASC mağaza yerelleştirmesi (İngilizce/Almanca keyword'lere Türkçe terimler,
   diaspora için) — plan dosyasının Faz 2 bölümünde, kod dışı.
8. Faz 3 (Aralık-Ocak, Ramazan 2027 = 8 Şub): Ramazan modu, Kur'an+meal, kaza takibi.

---

## Geçmiş — 1.6 (9) yayında
**1.6 (9) App Review'dan geçti ve yayınlandı** (28 Ağu 2026). İçeriği: Ayarlar ekranına
"yeni sürüm mevcut" bildirimi (`AppUpdateChecker` — iTunes Lookup API ile kontrol,
tıklanınca App Store sayfasına yönlendirir, Trendyol tarzı). `xcodegen generate` +
`./scripts/verify-xcode-cloud.sh` yeşil, 12 yeni birim testi
(`SekineTests/AppUpdateCheckerTests.swift`) dahil tüm testler geçiyor.

Bu sürümle birlikte mağaza görselleri de güncellendi: `store/screenshots-marketing-6.5/`
ve `store/screenshots-watch/`'a eklenen yeni AI-üretimi tanıtım görselleri yanlış
boyutlardaydı (852×1846 / 853×1844) — hepsi kırpılıp doğru ASC boyutlarına
(6.5": 1284×2778, Watch: 422×514) getirildi.

1.5'in içeriği (1.4'ü review ederken bulunan iki gerçek hata):
- **Kıble artık asla doğrulanmamış koordinattan çizilmiyor.** İl/ilçe seçicisi geocode
  başarısız olunca sessizce `39.0/35.0` (Kırşehir civarı) saklıyordu → kullanıcı uyarısız
  yanlış yöne yöneliyordu. Ayrıca konum hiç yokken açı 0'da kalıp **kuzeyi kıble**
  gösteriyordu. Koordinatlar opsiyonel yapıldı, placeholder kaldırıldı; izin varsa açı
  **gerçek GPS'ten** hesaplanıyor, hesaplanamıyorsa yön yerine konum izni isteniyor.
- **Drift uyarısına 25 km mesafe eşiği.** Yalnızca ilçe ID'si karşılaştırıldığı için,
  ilçe sınırına yakın oturan kullanıcı evindeyken uyarı alabiliyordu.

Gerekçeler `docs/decisions.md` (2026-08-24). Doğrulama: bağımsız hesaplanan kıble
açılarıyla karşılaştırıldı (Ankara canlı GPS 160° / beklenen 160.1; legacy 1.4 verisi
152° / beklenen 151.6), mesafe eşiği kontrol testiyle, 16/16 birim testi, iOS+watchOS
derlemesi.

**ASO baseline (24 Ağu 2026, 1.4 yayınlanmadan önce):** "ezan vakti" aramasında ~70. sıra.
1.4 çıktıktan 1-2 hafta sonra aynı aramalar tekrarlanıp karşılaştırılacak.

> 1.4'ün hazırlanış süreci (review bulguları, şema düzeltmesi, ASO metadata gerekçesi)
> artık kapandı — detay için `docs/decisions.md` (2026-08-23/24) ve git log
> (`f69c195`, `d52d5e8`, `50850cf`).

## DONE
Sürüm bazlı özet `PLAN.md`'de. Buraya yalnızca tekrar araştırılması pahalı olan bağlam:

- **Faz E4 (Apple Watch)** — Core kodu değişmeden watch hedefinde derlendi. Uygulama
  sırasında çözülen 3 gerçek sorun: `UNNotificationSound(named:)` watchOS'ta yok (sistem
  sesine düşülüyor), Swift 6 concurrency (nonisolated erişim), bildirim izni her açılışta
  isteniyordu (artık yalnızca onboarding'te). WatchConnectivity `xcrun simctl pair` ile
  uçtan uca doğrulandı. Watch app'in TAMAMI premium kilidinde (bilinçli tasarım) →
  ekran görüntüsü almak için `-uiTestForcePremium` gerekiyor.
- **Xcode Cloud CI** çalışır durumda; Build + Test kurulumu 24 Ağu 2026'da yeşil doğrulandı
  (ilk kez testler de CI'da koşuyor). Build 1'den 19'a kadar hiç yeşil
  build yoktu; Xcode Cloud hiç kullanılmıyordu, tüm gönderimler Xcode GUI'den elle
  yapılıyordu. `ci_scripts/ci_post_clone.sh` her çalışmada `xcodegen generate` + paket
  resolve yapıyor ve Xcode Cloud'un zorladığı `IDEPackageOnlyUseVersionsFromResolvedFile`/
  `IDEDisableAutomaticPackageResolution` defaults'larını temizliyor. Detay:
  `docs/decisions.md` (2026-08-20). **Kural: `project.yml`/`ci_scripts/` değişince
  push'tan önce `./scripts/verify-xcode-cloud.sh` çalıştır.**
  Workflow **Archive/export yapmıyor**, yalnızca Build + Test koşuyor (24 Ağu 2026 kararı,
  bkz. `docs/decisions.md`): export edilen üç dağıtım paketi hiç kullanılmıyordu ve
  imzalama yüzünden CI'ı sürekli kırmızı tutuyordu. Release arşivi Xcode'dan elle alınır.
  **Workflow'un güncel hâli** (ASC'de tutuluyor, repoda değil — sıfırlanırsa referans):
  · Test - iOS → Platform iOS, Scheme `Sekine`, Required to Pass, Test (Use Scheme Setting),
    Destination "Recommended iPhones" / Latest from Selected Xcode
  · Build - iOS → Platform iOS, Scheme `Sekine`, Build For "Any iOS Device"
  · Post-Actions: BOŞ (TestFlight/App Store dağıtımı yok — imzalama hatası buradan geliyordu)
  Tek `Sekine` şeması iPhone + Widget + Watch + komplikasyonları birlikte derler (Watch
  gömülü bağımlılık); ayrı watchOS action'a gerek yok.

## NEXT
1. Kullanıcı: `feat/yearly-subscription` ve `feat/international-locations`'ı gözden
   geçir, `main`'e merge et (Faz 2 branch'i henüz commit edilmedi, önce commit'le).
2. Kullanıcı: ASC'de yıllık abonelik ürününü oluştur (`com.sekineapp.sekine.premium.yearly`).
3. Kullanıcı: gerçek cihazda sandbox satın alma/restore testi (ömürlük + yıllık).
4. Kullanıcı: gerçek cihazda yurt dışı bir konum için vakitleri Diyanet siteyle karşılaştır.
5. Kullanıcı: 1.7'yi gönder (ASC taslağı zaten hazır — bkz. CURRENT TASK).
6. 2-3 hafta sonra ASC Analytics'e tekrar bak: dönüşüm ve "ezan vakti" sırası değişti mi,
   ölç.
7. Gerçek cihaz/TestFlight gerektiren doğrulamalar: uzun süreli bildirim + BG-refresh
   güvenilirliği, Watch bildirim dedup'ı, kıble pusulası.
8. Gelir zinciri (kod dışı): 20/B istisna belgesi + özel hesap gelince ASC'de IBAN güncelle.
9. (Opsiyonel) İstanbul dışı illerde eksik ilçe talebi gelirse il-bazlı doğrulayarak alias ekle.
10. Faz 3 (Aralık-Ocak): Ramazan modu, Kur'an+meal, kaza takibi.

## BLOCKERS
Yok — ama 1.7 submit, yıllık abonelik ve yurtdışı desteğinin canlıya çıkışı yukarıdaki
kullanıcı aksiyonlarına (ASC ürün oluşturma + gerçek cihaz testleri) bağlı.

## BEST AGENT NOW
Claude — ürün/veri kararı gerektiren işler sürüyor.

---

## Referans notları (sık aranan, tekrar araştırmaya gerek yok)

> Apple ID/Team, bundle ID'ler, gönderim adımları, mağaza metinleri ve geçmişte çözülen
> gönderim hataları → `docs/store-submission.md`.

**Repo görünürlüğü PUBLIC kalmalı:** Support URL + Privacy Policy URL repo'ya bağlı (ASC
gereksinimi); private yapılırsa App Store'daki linkler kırılır. Bilinçli karar.

**AB erişilebilirliği:** 27 AB ülkesinde "Cannot Sell" idi (DSA Trader Status eksikti) →
kullanıcı "non-trader" seçti, global erişilebilirlik açıldı, İspanya'dan test indirmesiyle
doğrulandı (20 Ağu 2026). Kapandı.

**ASC Paid Applications Agreement:** imzalandı (20 Ağu 2026), geçici/başka-iş banka
hesabıyla — 20/B istisna belgesi + özel hesap gelince IBAN güncellenecek. Artık gelir
zincirinin önünde engel değil.

**Ezan ses dosyaları — ERTELENDİ:** CC0 adaylar bulundu (Madinah Fajr Azan - Sheikh Faisal
Numan, archive.org; Beautiful adhan.ogg, Wikimedia) ama "makam-bazlı 5 ayrı vakit" seti
(İlhan Tok / Abc Müzik) ticari lisans gerektiriyor. Gerekirse: `ezan.caf` (≤30sn bildirim
tonu) + `ezan-full.m4a` (in-app tam ezan) → `Sekine/Resources/Audio/`; kod dosyalar eklenince
otomatik aktifleşir (gate açık, dosya yoksa özellik sessizce pasif).

**İl/ilçe verisi:** kaynak ezanvakti.emushaf.net (Diyanet aynası), bazı isimler ASCII-hasarlı
ve İstanbul'da ~20 ilçe eksik (merkez 9541 altında veriliyor). Çözüm:
`Sekine/Core/Location/LocationOverrides.json` — 434 ad düzeltmesi + İstanbul ilçe alias'ları
(aynı IlceID → aynı vakit, güvenli). Bilinçli karar: diğer illerde toptan ilçe eklenmedi
(Antalya/Muğla gibi coğrafi geniş illerde merkeze bağlamak yanlış vakit riski taşır) — talep
gelirse il-bazlı doğrulanarak eklenmeli.
