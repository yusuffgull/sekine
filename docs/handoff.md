# Handoff

## CURRENT TASK — Büyüme/gelir planı: Faz 1/2/3 kod tarafı `integration/all-features`'te birleşik
**23-24 Eyl 2026.** Plan: `/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`.
Gerekçeler: `docs/decisions.md` (2026-09-23/24 girdileri).

**Durum:** `main` yalnızca Faz 0 (ASO) içerir. Yedi bağımsız feature branch var VE hepsi
`integration/all-features`'te birleştirildi (109 test yeşil) (yalnızca docs çakışması, koda dokunmadı;
birlikte derleniyor/testler geçiyor — bkz. aşağıdaki doğrulama). Merge için tek karar:
`integration/all-features`'i main'e almak (ya da branch'leri tek tek).

| Branch | İçerik | Review |
|---|---|---|
| `main` | Faz 0 ASO — ASC'ye canlı (1.6 Promo Text) + 1.7 taslağı (submit EDİLMEDİ) | — |
| `feat/yearly-subscription` | yıllık abonelik ₺149.99 + 7 gün deneme | NATASHA ✓ |
| `feat/international-locations` | yurtdışı + KRİTİK tz düzeltmesi (sabit Istanbul) | VISION ✓ |
| `feat/kaza-tracking` | kaza namazı sayaç/seri (premium istatistik) | test + simülatör |
| `feat/ramadan-mode` | sahur/iftar geri sayımı, hicri veriden | test + simülatör |
| `feat/share-card` | paylaşılabilir vakit kartı (filigranlı) | test + PNG gözle |
| `feat/fasting-tracker` | oruç günü takibi (Ramazan kartında) | test + simülatör |
| `feat/live-activity` | iftar Live Activity (kilit ekranı/Dynamic Island) | test + Activity.request simülatörde; Dynamic Island cihazda gözle kontrol edilmeli |

**Bilinçli yapılmayanlar (kayıtlı, kullanıcı kararı gerekir):** çok aylık imsakiye
(2026-09-08 kararı), Kur'an+meal (Tanzil meal lisansı ticari kullanıma kapalı), AI ezan
(ElevenLabs hesabı yok + TTS makam okuyamaz).

**Kullanıcı aksiyonları:** (1) branch/integration'ı incele ve merge et; (2) ASC'de yıllık
abonelik ürününü oluştur (`com.sekineapp.sekine.premium.yearly`); (3) gerçek cihazda
sandbox satın alma/restore + yurt dışı konum vakitlerini Diyanet siteyle karşılaştır;
(4) 1.7'yi submit et (ASC taslağı hazır); (5) Featuring nomination, Search Ads (10-30$/ay),
In-App Events, diaspora için İngilizce/Almanca keyword yerelleştirmesi.

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
1. Kullanıcı: `integration/all-features`'i incele → main'e merge (yukarıdaki aksiyonlar).
2. 2-3 hafta sonra ASC Analytics: dönüşüm ve "ezan vakti" sırası değişti mi.
3. Karar bekleyenler: Kur'an lisans yolu, çok-ay imsakiye, ezan (müezzin kaydı).
4. Ayrı turlar: Ramazan Live Activity, oruç günü takibi, Onboarding/watch ülke seçici.
5. Gerçek cihaz: uzun süreli bildirim + BG-refresh, Watch dedup, kıble pusulası.
6. Gelir zinciri (kod dışı): 20/B belgesi + özel hesap → ASC IBAN.

## BLOCKERS
Yok — ama canlıya çıkış kullanıcı aksiyonlarına (ASC ürün, cihaz testleri, merge) bağlı.

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
