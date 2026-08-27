# PLAN

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

**1.6 (9) kod tarafı tamam, gönderim bekliyor:** Ayarlar ekranına, App Store'da yeni
sürüm varsa bildirim gösteren ve tıklanınca App Store sayfasına yönlendiren bir satır
eklendi (`AppUpdateChecker`, iTunes Lookup API, Trendyol tarzı). Detay: `docs/handoff.md`.

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
- Ayrı `DiyanetDirectory` örnekleri (SekineApp/Settings/Onboarding/LocationSearchSheet)
  il/ilçe listesini ayrı ayrı indirebiliyor → tek örneği paylaştırmak temiz bir iyileştirme.
- `project.yml` veya `ci_scripts/` değişince push'tan ÖNCE `./scripts/verify-xcode-cloud.sh`.

## Sonraki (henüz başlanmadı)
- ASO: metadata güncellemesi 1.4 ile girilecek; yayından ~1 hafta sonra App Analytics'e
  bakıp Apple Search Ads'e başvurulup başvurulmayacağına karar verilecek.
- Android (Kotlin, ayrı repo), globalleşme (i18n, dünya konumları), ayet paylaşımı.
