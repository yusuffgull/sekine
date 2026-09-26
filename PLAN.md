# PLAN

## Faz 0 — Büyüme/gelir planı: ASO refresh (23 Eyl 2026, sürüyor)
1 yıllık büyüme/gelir yol haritası kabul edildi:
`/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`.
Gerekçe: `docs/decisions.md` (2026-09-23). Detay: `docs/handoff.md`.

- [x] ASC Analytics + rakip yorum analizi
- [x] Keywords, Promotional Text, açıklama gerekçesi güncellendi (`docs/store-submission.md`)
- [x] Ekran görüntüsü sırası değişti + yeniden üretildi
- [x] ASC'de 1.7 taslak sürümü açıldı, yeni metin/görseller girildi (submit EDİLMEDİ —
      sandbox test bekliyor)
- [ ] Kullanıcı: gerçek cihazda sandbox satın alma testi, sonra 1.7'yi submit et
- [x] Faz 1: yıllık abonelik (ASC'de ürün oluşturma + sandbox testi kullanıcıda)
- [x] Faz 2: yurtdışı konum + kritik saat dilimi düzeltmesi (gerçek cihazda Diyanet
      karşılaştırması kullanıcıda)
- [ ] Faz 3 (Ramazan 2027 = 8 Şub):
  - [x] Kaza namazı takibi
  - [x] Ramazan modu sayacı (sahur/iftar)
  - [x] Paylaşılabilir vakit kartı
  - [ ] Çok aylık/yıllık imsakiye — kullanıcı 2026-09-27'de ONAYLADI: yakın 32 gün Diyanet + ötesi çevrimiçi "yaklaşık" (etiketli, iftar güvenlik payı); sıradaki iş (decisions 2026-09-27)
  - [ ] Kur'an+meal — lisans engeli; kullanıcıyla TARTIŞMA açık (seçenekler decisions 2026-09-27)
  - [ ] Ezan sesi AI denemesi — kullanıcı kararı: önce ElevenLabs ücretsiz, olmazsa ücretli; hesap/anahtar kullanıcıda, panel kapısı geçerli (decisions 2026-09-27)
  - [x] Oruç günü takibi (`feat/fasting-tracker`, integration üstünde)
  - [x] Ramazan iftar Live Activity (`feat/live-activity`; Dynamic Island cihazda gözle kontrol edilmeli)
  - [ ] In-App Events — metin taslakları hazır (`docs/in-app-events.md`), tarih doğrulama + ASC girişi kullanıcıda

## Durum
**1.3 App Store'da yayında** — Ömürlük Premium + Bağış (StoreKit 2), ücretsiz Zikir
sekmesi ve Apple Watch companion app dahil. Yani Faz 1, 1.2, 1.3 ve Faz 2'nin tamamı
(E4 dahil) kullanıcıya ulaştı.

**1.4 (7) yayında.** İçeriği: rating isteme + Değerlendir/Paylaş, konum otomatik
güncelleme (seyahat), Ayarlar'da GPS butonu, Cuma/ayet-dua saati açıklamaları, bağış
butonu race düzeltmesi.

**1.5 (8) yayında** (27 Ağu 2026): kıble artık asla doğrulanmamış koordinattan
çizilmiyor (geocode başarısızlığında saklanan sahte koordinat kaldırıldı; izin varsa
gerçek GPS kullanılıyor) + drift uyarısına 25 km mesafe eşiği.
Detay: `docs/handoff.md`, gerekçe: `docs/decisions.md`.

**1.6 (9) yayında** (28 Ağu 2026): Ayarlar ekranına, App Store'da yeni sürüm varsa
bildirim gösteren ve tıklanınca App Store sayfasına yönlendiren bir satır eklendi
(`AppUpdateChecker`, iTunes Lookup API, Trendyol tarzı). Detay: `docs/handoff.md`.

**1.7 (henüz yayınlanmadı, 2026-09-08) — sessiz hata düzeltmeleri + StoreKit
güvenilirliği.** Stark Industries Avengers kadrosu (JARVIS/VISION/BANNER) ile
uçtan uca yapıldı, çoklu VISION review turlarından geçti:
- Ezan bildirim sesi seçici artık dosya yoksa gizleniyor + mevcut kullanıcıların
  bozuk state'i migrasyonla düzeltildi (commit `9b6e71b`).
- `LocationManager` race condition single-flight pattern ile çözüldü.
- `RollingScheduler` (bildirim planlama) baştan yazıldı: actor + gerçek FIFO,
  stabil identifier + otomatik replace, transactional-benzeri reconciliation,
  legacy migrasyon. 6 tur review, kalan 3 küçük bulgu (kuyruk-önceliği, markExpired
  yarışı, injection-hatası-başarı-sayılması) ayrı bir takip turunda ele alınacak.
- `Store.swift` (StoreKit entitlement) baştan yazıldı: nesil-korumalı single-flight
  refresh, `EntitlementState` (loading/owned/notOwned/indeterminate), revocation
  `Transaction.updates`'e taşındı, `RestoreOutcome`. 6 tur review sonrası mevcut
  haliyle kabul edildi — kalan 6 bilinen risk `docs/decisions.md` 2026-09-08'de
  kayıtlı, ayrı bir StoreKit-v2 turu gerektiriyor.
- `RollingScheduler` 7 tur review + bir gerçek test-kilitlenmesi düzeltmesinden
  sonra mevcut haliyle kabul edildi — kalan 2 bilinen risk (düşük ciddiyet,
  BGTask zaman-aşımı kenar durumları) `docs/decisions.md` 2026-09-08'de kayıtlı.
- **Henüz yapılmadı:** gerçek cihazda sandbox satın alma/restore testi, App Store
  submission. Ezan ses dosyası (CC0 aday bulundu, kullanıcı onayı bekliyor),
  imsakiye çok-ay genişletmesi (kaynak kısıtı nedeniyle ertelendi) bu sürüme dahil
  değil.

## Yayınlanan sürümler
- **1.0** — vakitler, geri sayım, aylık imsakiye, kıble, bildirimler, widget. Diyanet
  birebir vakit kaynağı (DiyanetProvider).
- **1.1** — yayın sonrası UX: bildirim metinleri, DynamicType, aylık otomatik yükleme,
  widget tanıtımı, 434 il/ilçe adı düzeltmesi.
- **1.2** — Time-Sensitive entitlement + "Odak modunda da uyar" (opt-in), kilit ekranı /
  StandBy widget'ları, hicri tarih, kıble saati; bildirim güvenilirliği (iki-geçişli
  bütçe, gece BGProcessingTask); Cuma/kandil/günlük ayet hatırlatmaları.
- **1.3** — Faz 2 tamamı: StoreKit 2 altyapısı, tam ezan mekanizması, premium temalar +
  alternatif ikon, ücretsiz Zikir sekmesi, çoklu konum, vakit-başına ses, premium widget
  accent, **Apple Watch app + komplikasyonlar + WatchConnectivity**.
- **1.4** — growth (rating isteme, Değerlendir/Paylaş) + konum otomatik güncelleme,
  Ayarlar'da GPS butonu, Cuma/ayet-dua saati açıklamaları, bağış butonu race düzeltmesi.

## Kullanıcı kapıları (kod dışı)
- [x] AB erişilebilirliği (non-trader, global)
- [x] ASC Paid Applications Agreement (geçici banka hesabıyla)
- [x] 4 IAP ürünü ASC'de oluşturuldu ve 1.3 ile onaylandı
- [ ] 20/B istisna belgesi + özel ticari hesap → gelince ASC'de IBAN güncelle (aciliyeti düşük)
- [ ] Ezan ses dosyaları — ERTELENDİ (lisans araştırması durduruldu; kod gate'i hazır,
      dosya eklenince otomatik aktifleşir)

## Açık işler / bilinen riskler
- Gerçek cihazda uzun süreli bildirim + BG-refresh güvenilirlik testi (kullanıcı).
- Kıble pusulası gerçek cihaz gerektirir (magnetometre); simülatörde yalnızca açı gösterilir.
- Watch bildirim dedup'ı (iki cihazda aynı anda tek bildirim) gerçek cihaz/TestFlight
  gerektiriyor, headless doğrulanamadı.
- ~~Ayrı `DiyanetDirectory` örnekleri~~ — tek örneğe indirildi (feat/polish-and-hardening).
- `project.yml` veya `ci_scripts/` değişince push'tan ÖNCE `./scripts/verify-xcode-cloud.sh`.

## Sonraki (henüz başlanmadı)
- ASO: metadata güncellemesi 1.4 ile girilecek; yayından ~1 hafta sonra App Analytics'e
  bakıp Apple Search Ads'e başvurulup başvurulmayacağına karar verilecek.
- Android (Kotlin, ayrı repo), globalleşme (i18n, dünya konumları), ayet paylaşımı.
