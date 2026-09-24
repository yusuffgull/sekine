# Handoff

## CURRENT TASK — Büyüme/gelir planı: Faz 0 canlı, Faz 1/2 kod bitti, Faz 3 başladı
**23-24 Eyl 2026:** ASC Analytics + 9 rakip uygulamanın 327 yorumu incelendi, 1 yıllık
yol haritası çıkarıldı: `/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`
(kullanıcı onayladı). Gerekçe özeti: `docs/decisions.md` (2026-09-23).

**DÖRT AYRI BRANCH var, main'e HİÇBİRİ merge edilmedi:**

| Branch | İçerik | Durum |
|---|---|---|
| `main` | Faz 0 (ASO) | ASC'ye canlı işlendi |
| `feat/yearly-subscription` | Faz 1 (yıllık abonelik) | kod hazır, NATASHA ✓ |
| `feat/international-locations` | Faz 2 (yurtdışı + kritik tz düzeltmesi) | kod hazır, VISION ✓ |
| `feat/kaza-tracking` | Faz 3'ün ilk parçası (kaza namazı takibi) | kod hazır |

**Faz 0 — tamamlandı, `main`'e merge edildi VE ASC'ye canlı işlendi:**
- Keywords, Promotional Text, açıklama gerekçesi güncellendi (`docs/store-submission.md`).
- Ekran görüntüsü sırası değişti, yeniden üretildi.
- **ASC canlı 1.6 sürümünde Promotional Text güncellendi** (Chrome ile, elle onaylı).
- **ASC'de "1.7 Prepare for Submission" taslağı açıldı** (yeni keywords/promo/açıklama/
  5 ekran görüntüsü), **submit EDİLMEDİ** — sandbox testi bekliyor.

**Faz 1 (`feat/yearly-subscription`):** `com.sekineapp.sekine.premium.yearly` (₺149.99,
7 gün deneme) ömürlüğün yanına eklendi. `Store.entitlementProductIDs` tek doğruluk
kaynağı. NATASHA (T3 güvenlik review) temiz raporu verdi.

**Faz 2 (`feat/international-locations`):** KRİTİK bug düzeltildi — `DiyanetProvider`
her konum için sabit `Europe/Istanbul` varsayıyordu, yurt dışında sessizce yanlış vakit
üretiyordu. Artık her günün gerçek UTC ofseti API'den okunuyor. Ülke seçimi eklendi
(105+ ülke, Diyanet servisi zaten destekliyor). VISION matematiksel doğrulama yaptı,
itiraz yok.

**Faz 3, ilk parça (`feat/kaza-tracking`):** `KazaTracker` — 5 vakit için kalan kaza
sayacı + tamamlama günlüğünden türetilen seri (streak). Ücretsiz: sayaçlar + seri.
Premium: 7/30 gün + toplam istatistik. `Sekine/Features/Spiritual/KazaView.swift`,
Zikir sekmesine eklendi. 11 yeni birim testi + simülatörde GERÇEKTEN çalıştırılıp
ekran görüntüsüyle doğrulandı (yalnızca statik derleme değil). Gerekçe:
`docs/decisions.md` (2026-09-24).

**Faz 3'ün kalanı (henüz başlanmadı):** çok aylık imsakiye, Kur'an+meal (veri/lisans
araştırması gerekiyor), Ramazan modu (Live Activity dahil), ezan sesi AI denemesi
(kullanıcının dinleyici paneli onayı gerekiyor), In-App Events (ASC, kod dışı).

**Henüz yapılmadı (ortak, kullanıcı aksiyonu):**
1. Dört branch'i incele, sırayla `main`'e merge et.
2. ASC'de yıllık abonelik ürününü oluştur.
3. Gerçek cihazda: sandbox satın alma testi + yurt dışı konum için Diyanet siteyle
   karşılaştırma.
4. 1.7'yi (tüm bu değişikliklerle) submit et.
5. ASC'de: keywords/promo/description, Featuring nomination, Search Ads.

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
1. Kullanıcı: `feat/yearly-subscription`, `feat/international-locations`,
   `feat/kaza-tracking`'i sırayla incele, `main`'e merge et.
2. Kullanıcı: ASC'de yıllık abonelik ürününü oluştur.
3. Kullanıcı: gerçek cihazda sandbox satın alma/restore testi + yurt dışı konum
   için Diyanet siteyle karşılaştırma.
4. Kullanıcı: 1.7'yi gönder (ASC taslağı zaten hazır).
5. 2-3 hafta sonra ASC Analytics'e tekrar bak: dönüşüm ve "ezan vakti" sırası değişti mi.
6. Faz 3'ün kalanı: çok aylık imsakiye → Kur'an+meal → Ramazan modu → ezan AI denemesi
   → In-App Events (sıra plan dosyasında).
7. Gerçek cihaz/TestFlight gerektiren doğrulamalar: uzun süreli bildirim + BG-refresh
   güvenilirliği, Watch bildirim dedup'ı, kıble pusulası.
8. Gelir zinciri (kod dışı): 20/B istisna belgesi + özel hesap gelince ASC'de IBAN güncelle.
9. (Opsiyonel) İstanbul dışı illerde eksik ilçe talebi gelirse il-bazlı doğrulayarak alias ekle.

## BLOCKERS
Yok — dört branch'in main'e merge edilmesi ve ASC/cihaz aksiyonları kullanıcıda.

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
