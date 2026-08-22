# PLAN

## Durum özeti
v1 App Store'da yayında. v1.1 gönderildi (review sonucu — bkz. `docs/handoff.md`).
Faz 2 (Ömürlük Premium + Bağış) neredeyse tamam; kalan tek parça **Faz E4 — Apple Watch
uygulaması**, kod tamam/uçtan uca doğrulandı, kalan kısım TestFlight/gerçek cihaz aşaması.

## Faz 1 — v1 iOS (App Store'a ilk çıkış) — TAMAMLANDI, YAYINDA
- [x] XcodeGen proje iskeleti, Core veri katmanı + testler, RollingScheduler bildirimleri
- [x] UI: Onboarding, Home, Monthly, Qibla, Settings; WidgetKit widget
- [x] Diyanet doğrulaması → birebir Diyanet kaynağına geçildi (DiyanetProvider)
- [x] Apple review geçildi → 1.0 "Ready for Distribution"

## v1.1 — yayın sonrası UX düzeltmeleri (14 Ağu 2026) — GÖNDERİLDİ
- [x] Bildirim metni sadeleştirme, onboarding hata metni düzeltmesi, DynamicType desteği
- [x] Aylık otomatik yükleme, widget tanıtımı, 434 il/ilçe adı düzeltmesi (bundle override)
- [x] Versiyon 1.1 (4) → Archive → Submit for Review (kullanıcı)

## Faz 1.2 — Güvenilirlik & tamamlama (ücretsiz) — KOD TAMAM, cihaz testi bekliyor
- [x] Time-Sensitive Notifications entitlement + "Odak modunda da uyar" opt-in toggle
- [x] Kilit ekranı / StandBy widget'ları (accessoryCircular/Rectangular/inline)
- [x] Hicri tarih (Home) + Kıble saati (Qibla) — Diyanet resmi verisinden
- [ ] Gerçek cihazda uzun süreli bildirim/BG-refresh güvenilirlik testi (kullanıcı, cihaz)
- [ ] Kilit ekranı widget'ları + Kıble pusulası gerçek cihaz doğrulaması (kullanıcı)

## Faz 1.3 — Bildirim güvenilirliği + yeni türler (ücretsiz) — KOD TAMAM
- [x] İki-geçişli bildirim bütçesi, gece BGProcessingTask
- [x] Cuma hatırlatması, kandil/bayram tebrikleri (Diyanet Hicri feed'inden türetilir)
- [x] Günlük ayet/dua rotasyonu; Ayarlar'da "Ek Hatırlatmalar" bölümü (Odak-delme opt-in)

## Faz 2 — Gelir modeli (Ömürlük Premium + Bağış, StoreKit 2, backend'siz) — DEVAM EDİYOR
- [x] A: StoreKit 2 altyapısı (Store/Paywall/restore/entitlement)
- [x] B: Tam ezan mekanizması (premium ses gate + in-app AdhanPlayer)
- [x] C1: Premium renk temaları · C2: alternatif app ikonu (ücretsiz)
- [x] D: Ücretsiz "Zikir" sekmesi (tesbih + Esmaül Hüsna + dualar)
- [x] E1: Çoklu konum (premium) · E2: vakit-başına özel ses (premium) · E3: premium widget accent
- [~] **E4: Apple Watch uygulaması** — kod tamam, `xcrun simctl pair` ile uçtan uca
      doğrulandı (bkz. `docs/handoff.md`). Kalan: gerçek dedup testi (iki cihaz aynı anda
      bildirim) ve premium ekranların görsel doğrulaması — ikisi de TestFlight/gerçek
      cihaz gerektiriyor, headless ortamda yapılamıyor. Aşama 7 (ASC hazırlığı) kod dışı.
      Detaylı plan: `~/.claude/plans/evet-project-yml-i-inceleyip-watchos-eager-bubble.md`.
- KULLANICI KAPILARI (kod dışı, bkz. `docs/handoff.md` gelir zinciri bölümü):
  - [x] AB erişilebilirliği (non-trader, global) — doğrulandı
  - [x] ASC Paid Applications Agreement — imzalandı (geçici banka hesabıyla)
  - [ ] 20/B istisna belgesi + özel ticari hesap (aciliyeti düşük)
  - [x] IAP product'ları ASC'de oluştur (kodla eşleşen ID) — 4 ürün de eklendi (22 Ağu 2026)
  - [ ] Ezan ses dosyaları — ERTELENDİ (lisans araştırması kullanıcı kararıyla durduruldu;
        kod gate'i hazır, dosya eklenince otomatik aktifleşir)

## Kalan genel işler / bilinen riskler
- Qibla pusulası gerçek cihaz gerektirir (magnetometre); simülatörde yalnızca açı gösterilir.
- Xcode Cloud: `project.yml` veya `ci_scripts/` her değiştiğinde push'tan önce
  `./scripts/verify-xcode-cloud.sh` çalıştırılmalı (bkz. `docs/decisions.md`, 2026-08-20).

## Faz 3 — Platform genişleme (sonraki)
- [ ] Android (Kotlin, ayrı repo)
- [ ] Globalleşme (i18n, dünya konumları), ayet paylaşımı, dini içerik
