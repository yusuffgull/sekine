# PLAN

## Faz 1 — v1 iOS (App Store'a ilk çıkış)
- [x] Repo + XcodeGen proje iskeleti
- [x] Diyanet doğruluk kararı (kaynak-bağımsız mimari; Aladhan method=13 default)
- [x] Core veri katmanı (model, provider, cache, fallback) + testler
- [x] RollingScheduler bildirim sistemi (64-pencere) + BG refresh + willPresent tazeleme
- [x] UI: Onboarding, Home (canlı geri sayım), Monthly, Qibla, Settings
- [x] Konum + ilçe arama
- [x] WidgetKit widget (sonraki vakit + geri sayım)
- [x] Uygulama ikonu + orijinal chime bildirim sesi
- [x] Build + testler (9/9 geçti) + simülatörde 5 ekran görsel doğrulama
- [x] GitHub'a push (private `yusuffgull/sekine`)
- [x] **Diyanet doğrulaması yapıldı** → birebir Diyanet kaynağına geçildi (DiyanetProvider)
- [x] App Store 6.9" ekran görüntüleri (`store/screenshots/`)
- [x] Store gönderimi: signing/team, ASC listing, archive, submit (KULLANICI — interaktif Apple)
- [x] **Apple review geçildi** → 1.0 "Ready for Distribution"; kullanıcı Release'e bastı

## Kalan genel işler / bilinen riskler
- Monthly/Qibla/Settings ekranları derlendi ama simülatörde görsel doğrulanmadı (tab tap otomasyonu yok).
- Qibla pusulası gerçek cihaz gerektirir (magnetometre); simülatörde yalnızca açı gösterilir.
- Bildirim güvenilirliği gerçek cihazda uzun süreli test edilmeli (BG refresh davranışı).

## v1.1 — yayın sonrası UX düzeltmeleri (14 Ağu 2026, REVIEW'DA)
- [x] Bildirim metinleri sadeleştirildi ("Akşam vakti girdi.", temenni yok)
- [x] Onboarding hatasından "Diyanet" çıkarıldı
- [x] Yazı boyutu tüm ekranlara uygulandı (Monthly XL satır atlaması dahil düzeltildi)
- [x] Aylık otomatik yükleme + sınırlı ay gezinme + net boş-durum
- [x] Widget tanıtımı (onboarding + Ayarlar bölümü)
- [x] İl/ilçe: 434 Türkçe ad düzeltmesi + İstanbul eksik ilçeleri (bundle override)
- [x] Versiyon 1.1 (4) bump, push, Archive → Submit for Review (kullanıcı)

## Faz 1.2 — Güvenilirlik & tamamlama (ücretsiz, çekirdek sözü güçlendir) — SIRADAKİ
- [ ] **Time-Sensitive Notifications entitlement** (`com.apple.developer.usernotifications.time-sensitive`)
      → İmsak/vakit bildirimleri Odak/Uyku/Rahatsız Etmeyin modunu delsin. Şu an
      `.timeSensitive` kodda var ama entitlement yok → sessizce `.active`'e düşüyor.
      EN YÜKSEK öncelik: çekirdek söz "güvenilir bildirim"i doğrudan etkiliyor.
- [ ] Kilit ekranı + StandBy widget'ları (accessoryCircular/Rectangular/inline)
- [ ] Orta boy widget: 5 vaktin tümü tek bakışta
- [ ] Gerçek cihazda uzun süreli bildirim/BG-refresh güvenilirlik testi
- [ ] Hicri tarih gösterimi (Home başlık) + kerahat/güneş bilgisi
- [ ] Kıble gerçek cihaz (magnetometre) doğrulaması

## Faz 2 — Monetizasyon (ücretsiz deneyim sağlamlaşınca)
- [ ] StoreKit 2 aboneliği → tam ezan sesi (peşpeşe bildirim), ezan ses seçenekleri
- [ ] PremiumGate zaten hazır; paywall + restore

## Faz 3 — Platform genişleme
- [ ] Apple Watch native app (complication + standalone bildirim)
- [ ] Android (Kotlin, ayrı repo)
- [ ] Globalleşme (i18n, dünya konumları), ayet paylaşımı, dini içerik
