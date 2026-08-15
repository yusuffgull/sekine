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

## Faz 2 — Gelir modeli (Ömürlük Premium + Bağış) — DEVAM EDİYOR
- [x] Faz A: StoreKit 2 altyapısı — Store (ürün/satın alma/restore/entitlement), Paywall,
      Ayarlar Premium + Destekle bölümleri, PremiumProviding bağlandı. Yerel .storekit test config.
- [x] Faz B: Tam ezan mekanizması — premium "Ezan" bildirim tonu (kilitli→paywall) +
      AdhanPlayer (in-app tam ezan) + Home "Ezanı Çal" (premium, ses varsa görünür).
- [x] Faz C1: Premium renk temaları (Zümrüt free + 4 premium, gating). C2 (alt ikonlar) →
      tasarım assetı bekliyor (ertelendi).
- [x] Faz D: Ücretsiz "Zikir" sekmesi — tesbih + Esmaül Hüsna (100) + dualar (12).
- [x] Faz E1: Çoklu konum (premium yer imleri + hızlı geçiş; ücretsiz tek konum).
- [x] Faz E2: Vakit-başına özel ses (premium).
- [x] Faz E3: Premium widget accent'i (seçili temayı widget'a yansıtır).
- [x] Faz C2: Alternatif app ikonu — Çınar'ın tasarımı ücretsiz seçenek (asset-katalog alt ikon).
- [ ] Faz E4: Apple Watch uygulaması (premium, büyük — token limiti sıfırlanınca ayrı oturum).
- KULLANICI KAPILARI (kod dışı): (1) ASC Paid Applications Agreement (banka+vergi),
  (2) IAP satınca trader status'e geç, (3) IAP product'ları ASC'de oluştur (kodla eşleşen ID),
  (4) ezan ses dosyaları (ezan.caf ≤30sn + ezan-full.m4a) lisanslı/orijinal eklenmeli.
- NOT: StoreKit satın alma akışı simülatörde .storekit config scheme'e seçilerek denenir
  (headless xcodebuild'de SKTestSession güvenilir değil); kod standart StoreKit 2.

## Faz 1.3 — Bildirim güvenilirliği + yeni türler (ücretsiz) — KOD TAMAM
- [x] Güvenilirlik: iki-geçişli bütçe (ana vakit ön-hatırlatmadan önce), didReceive
      tazelemesi, gece BGProcessingTask.
- [x] Cuma hatırlatması (haftalık repeating), varsayılan AÇIK.
- [x] Kandil & bayram tebrikleri — Diyanet Hicri feed'inden TÜRETİLİR (HolyDays.json,
      Hicri-ay/gün eşleşmesi; Regaib = Recep ilk Cuma). Yıllık bakım yok. Varsayılan AÇIK.
- [x] Günlük ayet/dua — özel günde temalı ayet, normalde 40'lık anlamlı rotasyon
      (DailyVerses.json). Varsayılan AÇIK. Ayarlarda saat seçilebilir.
- [x] Ayarlar "Ek Hatırlatmalar" bölümü (toggle + saat picker). Odak-delme opt-in kalır.
- Not: bildirim içeriği/idrak-zamanı (kandil eve, bayram sabah) cihazda gözlemlenip
  ince ayar yapılabilir; içerik JSON'ları kolayca güncellenir.

## Faz 1.2 — Güvenilirlik & tamamlama (ücretsiz) — KOD TAMAM (cihaz testi bekliyor)
- [x] **Time-Sensitive Notifications entitlement** + **"Odak modunda da uyar" opt-in toggle**
      (Ayarlar). Varsayılan KAPALI → kullanıcı istemezse Odak/Uyku'yu delmez. Onay verirse
      `.timeSensitive`, aksi halde `.active`. (Cihaz arşivinde Automatic Signing capability'yi ekler.)
- [x] Kilit ekranı + StandBy widget'ları: accessoryCircular/Rectangular/inline eklendi
- [x] Orta boy widget zaten 5 vaktin tümünü gösteriyordu (doğrulandı)
- [x] Hicri tarih (Home) + Kıble saati (Qibla) — Diyanet resmi verisinden (HicriTarihUzun,
      KibleSaati). Kerahat için ayrı Diyanet verisi YOK → uydurulmadı, eklenmedi.
- [ ] Gerçek cihazda uzun süreli bildirim/BG-refresh güvenilirlik testi (kullanıcı, cihaz)
- [ ] Kilit ekranı widget'larının gerçek cihazda görsel doğrulaması (kullanıcı)
- [ ] Kıble pusulası gerçek cihaz (magnetometre) doğrulaması (kullanıcı)
- Tümü doğrulanınca: versiyon 1.2 / build 5 bump → Archive → Submit (v1.1 onaylandıktan sonra)

## Faz 2 — Monetizasyon (ücretsiz deneyim sağlamlaşınca)
- [ ] StoreKit 2 aboneliği → tam ezan sesi (peşpeşe bildirim), ezan ses seçenekleri
- [ ] PremiumGate zaten hazır; paywall + restore

## Faz 3 — Platform genişleme
- [ ] Apple Watch native app (complication + standalone bildirim)
- [ ] Android (Kotlin, ayrı repo)
- [ ] Globalleşme (i18n, dünya konumları), ayet paylaşımı, dini içerik
