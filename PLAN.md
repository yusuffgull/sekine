# PLAN

Yol haritası: `/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`
(gerekçe: `docs/decisions.md` 2026-09-23). Devir durumu: `docs/handoff.md`.

## Durum (29 Eyl 2026)
**Yayında: 1.6 (9).** **1.7 (10) hazır, henüz gönderilmedi** — `main`'de, sürüm numarası
yükseltildi. İçeriği:
- Yıllık abonelik (₺149.99, 7 gün deneme) + ömürlük yan yana; StoreKit entitlement
  katmanı baştan yazıldı, restore zaman aşımı düzeltmesi.
- Yurtdışı konum (ülke seçici, GPS ile ülke tespiti) + **kritik saat dilimi düzeltmesi**
  (yurtdışı vakitler artık sabit `Europe/Istanbul` ile hesaplanmıyor).
- Ramazan modu (sahur/iftar sayacı), oruç günü takibi, iftar Live Activity (kilit ekranı +
  Dynamic Island, uygulama içi anahtarla).
- Kaza namazı takibi (sayaç + seri ücretsiz, geçmiş istatistik premium).
- Paylaşılabilir vakit kartı (filigranlı).
- Bildirim planlayıcı (`RollingScheduler`) baştan yazıldı: sessiz bildirim kaybı ve
  çoklu-instance race kapandı; ezan sesi seçici + LocationManager race düzeltmeleri.
- Watch onboarding'e ülke seçici; tek `DiyanetDirectory` örneği.
- ASO: yeni keywords/promo text/ekran görüntüsü sırası (Faz 0).

## Gönderim öncesi kalan (kullanıcı)
- [ ] Gerçek cihazda sandbox satın alma + restore (yıllık ve ömürlük)
- [ ] ASC'de yıllık abonelik ürünü: `com.sekineapp.sekine.premium.yearly` (₺149.99, 7 gün deneme)
- [ ] Yurtdışı konum vakitlerini (Almanya/Hollanda) Diyanet sitesiyle karşılaştır
- [ ] Dynamic Island'ı cihazda gözle kontrol et
- [ ] Archive → ASC → What's New → Submit (adımlar: `docs/store-submission.md`)

## Sonraki işler (Ramazan 2027 ≈ 8 Şub — hedef: 15 Ocak'ta mağazada)
- [ ] **Çok aylık/yıllık imsakiye** — kullanıcı onayladı (2026-09-27): yakın 32 gün Diyanet
      birebir + ötesi çevrimiçi "yaklaşık" (etiketli). **İftar için ≥2 dk güvenlik payı şart**
      (Aladhan akşamı 1–2 dk erken veriyor). Önce kaynak kararı + çok şehir/mevsim ölçümü.
- [ ] **Kur'an+meal** — lisans engeli (Tanzil meal ticari kullanıma kapalı). Kullanıcıyla
      tartışma açık; öneri: önce resmî siteye bağlantı + Diyanet izin yazışması
      (`docs/decisions.md` 2026-09-27).
- [ ] **Ezan sesi** — kullanıcı ElevenLabs anahtarını hazırlayınca dinleme testi; 3–5 kişilik
      dinleyici paneli kapısı; olmazsa yerel müezzin kaydı. Kod kapısı hazır: dosya
      (`ezan.caf`, `ezan-full.m4a` → `Sekine/Resources/Audio/`) eklenince aktifleşir.
- [ ] **In-App Events** — metinler hazır (`docs/in-app-events.md`); tarih doğrulama + ASC girişi kullanıcıda
- [ ] Featuring nomination (Aralık başına kadar), Search Ads (10–30$/ay)
- [ ] Diaspora için İngilizce/Almanca keyword yerelleştirmesi (ASC, kod dışı)
- [ ] 2–3 hafta sonra ASC Analytics: dönüşüm (hedef ≥%1.6), "ezan vakti" sırası (baseline ~70)

## Bilinen riskler / açık
- Gerçek cihaz gerektirenler: uzun süreli bildirim + BG-refresh güvenilirliği, Watch bildirim
  dedup'ı, kıble pusulası (magnetometre).
- Onboarding (iPhone) manuel arama hâlâ yalnızca Türkiye; GPS akışı ülkeyi otomatik bulur.
- Abonelik sessiz süre dolumu ancak sonraki açılış/restore taramasında fark edilir (bilinçli).
- Kalan kozmetik StoreKit riskleri #1/#2/#3/#5 (`docs/decisions.md`, düşük öncelik).
- `project.yml` / `ci_scripts/` değişince push'tan ÖNCE `./scripts/verify-xcode-cloud.sh`.

## Kapanmış kapılar
- [x] AB erişilebilirliği (non-trader, global) — 20 Ağu 2026
- [x] ASC Paid Applications Agreement — 20 Ağu 2026
- [x] 4 IAP ürünü (1.3 ile onaylı)
- [x] **20/B istisna belgesi + özel ticari banka hesabı ASC'ye eklendi — 29 Eyl 2026**
      (geçici hesap değişti; gelir zincirinin önünde engel kalmadı)
- [x] Faz 0 ASO: ASC'de 1.7 taslağı açıldı, yeni metin/görseller girildi

## Yayınlanan sürümler
- **1.0** — vakitler, geri sayım, aylık imsakiye, kıble, bildirimler, widget; Diyanet birebir.
- **1.1** — UX: bildirim metinleri, DynamicType, aylık otomatik yükleme, 434 il/ilçe adı düzeltmesi.
- **1.2** — Time-Sensitive + "Odak modunda da uyar", kilit ekranı/StandBy widget'ları, hicri
  tarih, bildirim güvenilirliği (iki-geçişli bütçe, gece BGProcessingTask), Cuma/kandil/ayet.
- **1.3** — StoreKit 2 (Ömürlük Premium + bağış), tam ezan mekanizması, premium temalar,
  ücretsiz Zikir sekmesi, çoklu konum, **Apple Watch app + komplikasyonlar**.
- **1.4** — rating isteme, konum otomatik güncelleme, GPS butonu, bağış butonu race düzeltmesi.
- **1.5 (8)** (27 Ağu) — kıble asla doğrulanmamış koordinattan çizilmez; drift uyarısına 25 km eşiği.
- **1.6 (9)** (28 Ağu) — "yeni sürüm mevcut" bildirimi (`AppUpdateChecker`).
