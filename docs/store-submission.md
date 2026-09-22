# App Store Gönderim Rehberi

Uygulama **yayında**. Bu dosya artık ilk-gönderim rehberi değil, **her güncelleme için**
tekrarlanan adımların ve değişmeyen referans bilgilerin listesi.

## Sabitler (değişmez)
- **Apple ID:** 6796900944 · **Team:** 33L468BTR2
- **Bundle ID'ler:** `com.sekineapp.sekine` (app), `.widget`, `.watchkitapp`,
  `.watchkitapp.complications`, `.tests`
- **App Group:** `group.com.sekineapp.sekine`
- **Privacy Policy URL:** https://github.com/yusuffgull/sekine/blob/main/PRIVACY.md
- **Support URL:** https://github.com/yusuffgull/sekine
- **App Privacy:** "Data Not Collected" (backend yok, analytics yok, reklam yok; konum
  yalnızca cihazda kullanılır, vakit servisine yalnızca il/ilçe veya koordinat gider)
- **Kategori:** Yaşam Tarzı · **Yaş sınırı:** 4+
- Signing otomatik; `DEVELOPMENT_TEAM` `project.yml`'de tanımlı, elle ayar gerekmez.

## Her güncellemede
1. **Versiyon/build:** `project.yml` → `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
   Yayına çıkmış bir versiyona yeni build EKLENEMEZ → yayındaysa versiyonu yükselt.
   Gömülü Watch app'in sürümü iOS ile aynı olmalı (XcodeGen `settings.base`'ten geliyor).
2. `xcodegen generate` → `./scripts/verify-xcode-cloud.sh` (derleme + CI senaryosu).
3. Xcode → scheme **Sekine** + "Any iOS Device" → Product → Archive → Distribute App →
   App Store Connect. (Şemalar `project.yml`'de tanımlı; yanlış şemayla extension
   arşivlememeye dikkat.)
4. ASC'de yeni sürümü oluştur → build'i seç → **What's New** yaz.
5. İlk kez eklenen IAP'ler bir app sürümüyle birlikte gönderilmek zorundadır; zaten
   onaylanmış IAP'leri tekrar iliştirmeye gerek yok.
6. **Submit for Review.**

## Ekran görüntüleri
- **iPhone 6.9" zorunlu** (1320×2868) → `store/screenshots/`; 6.5" (1284×2778) →
  `store/screenshots-6.5/`.
- **ASC'ye yüklenecek asıl görseller artık bunlar — cihaz çerçeveli + başlıklı:**
  `./scripts/generate-store-screenshots.sh` → `store/screenshots-marketing/` (1320×2868,
  6.9" boyutuna hazır) + `store/screenshots-marketing-6.5/` (1284×2778, aynı render'dan
  resize). Ham `store/screenshots/`'daki çerçevesiz görüntüleri kaynak alır, WKWebView
  tabanlı HTML/CSS render (`scripts/html-to-png.swift`) ile işler, marka rengi arka plan
  (#1F6E5C, AccentColor) + Türkçe başlık ekler. Başlık metinleri script içinde tanımlı —
  yeni ekran eklenirse script'e yeni bir `render` çağrısı eklenir. Apple, gerçek uygulama
  içeriğini gösteren çerçeveli/metinli ekran görüntülerine izin verir (yaygın pratik).
- **Sıra (2026-09-23'te değişti):** `1-home, 2-onboarding, 3-qibla, 4-monthly, 5-settings`.
  Arama sonucunda yalnızca ilk 2-3 görsel görünür; eskiden 1. sırada onboarding (marka
  tanıtımı) vardı, gerçek uygulama ekranı (ana ekran) 2. sıraya kadar görünmüyordu. ASC'de
  görsellerin sırası dosya adından değil elle sürükle-bırak'tan gelir — yükleme sırasında
  bu sıra takip edilecek.
- **Apple Watch zorunlu** (binary Watch app içerdiği için) — 422×514 (Ultra 3) kabul edilir.
- Yakalama: `xcrun simctl io booted screenshot ekran.png`. Premium-kilitli ekranlar için
  DEBUG launch argümanları: `-uiTestSeedIstanbul`, `-uiTestForcePremium`, `-uiTestTab <id>`,
  `-uiTestShowPaywall`, `-uiTestScrollTo <id>`.
- Kıble ekranını simülatörde çekme — manyetometre olmadığı için "pusula yok" boş-durumu
  görünür.

## Mağaza metinleri

**ASO metadata (arama ağırlığı: App Name > Subtitle > Keywords; Description aramada
kullanılmaz):**
- **App Name:** `Sekine: Ezan ve Namaz Vakti`
- **Subtitle:** `Kıble, İmsakiye, Ezan Saatleri`
- **Keywords (2026-09-23 güncellendi):**
  `vakitleri,saati,imsakiye,iftar,sahur,ramazan,kuran,kıble,pusula,diyanet,dua,zikirmatik,tesbih,hicri,cuma`
  Eskisi App Name'de zaten geçen `ezan,namaz,vakit` kelimelerini tekrarlıyor ve Apple
  bunları başlıktan ayrıca indeksliyor — boşa alan kaplıyordu. Ayrıca düşük hacimli
  `sabah,öğle,ikindi,akşam,yatsı` çıkarıldı, yerine rakip yorum analizinde talep görülen
  `ramazan,iftar,sahur,kuran` ve sevilen özellik kelimeleri (`zikirmatik,tesbih`) eklendi.
  Gerekçe: `/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`.
- **Promotional Text (build gerektirmez, ASC'den anında güncellenir):**
  `Reklam yok, uygunsuz içerik yok, takip yok. Diyanet vakitleri, ailenizin tüm
  büyüklerine gönül rahatlığıyla.`

**Açıklama:**
> Sekine; namaz vakitlerini sade, huzurlu ve güvenilir biçimde sunar.
>
> • Reklamsız — hiçbir reklam, hiçbir dikkat dağıtıcı yok.
> • Gizli — verileriniz cihazınızdan çıkmaz, hiçbir takip yok.
> • Diyanet uyumlu — Türkiye vakitleri, çevrimdışı çalışır.
> • Güvenilir bildirimler — vakit bildirimleri düzenli yenilenir, susmaz.
> • Widget'lar — ana ekran, kilit ekranı ve StandBy'da sonraki vakit ve geri sayım.
> • Kıble pusulası ve aylık imsakiye.
> • Zikir — tesbih, Esmaül Hüsna ve dualar. Ücretsiz.
> • Apple Watch uygulaması ve komplikasyonlar.
> • Her yaşa uygun — büyük, net, anlaşılır tasarım.
>
> Reklam yok. Abonelik yok. Dilerseniz tek seferlik Premium ile destek olabilirsiniz.

**Neden bu metinler:** Rakip uygulamaların (9 uygulama, 327 yorum) şikayet analizinde
açık ara #1 şikayet reklam (uygunsuz reklam, açılışta tam ekran reklam yüzünden
uzun süreli kullanıcı kaybı). Sekine'nin reklamsız olması en güçlü fark, description ve
promo text bunu öne çıkarıyor.

## Review notları (App Review'a)
- Hesap/giriş gerektirmez, test hesabı gerekli değildir.
- Konum izni: yalnızca namaz vakti hesabı için, cihazda kullanılır; sunucuya kimlik
  bilgisi göndermez.
- Uygulama ücretsizdir; isteğe bağlı IAP: "Sekine Premium" (ömür boyu, tek seferlik,
  `com.sekineapp.sekine.premium.lifetime`) ve 3 bağış (`tip.small/medium/large`,
  consumable). IAP'siz de uygulama tam işlevseldir (Zikir sekmesi, vakitler, bildirimler
  ücretsiz) — premium yalnızca tam ezan sesi, ek temalar, çoklu konum gibi ekstraları açar.
- Apple Watch companion app dahildir (`SekineWatch`), iPhone'dan bağımsız da çalışır
  (`WKRunsIndependentlyOfCompanionApp: true`).

## Geçmişte çözülen gönderim sorunları (tekrarında referans)
- **90474 (iPad orientation)** → `TARGETED_DEVICE_FAMILY=1` her hedefte AYRI yazılmalı;
  XcodeGen proje-base ayarı target seviyesini ezmiyor.
- **codesign "resource fork/detritus"** → DerivedData'yı iCloud'lu `~/Documents` dışına ver.
  (Xcode GUI varsayılanı `~/Library` kullandığı için GUI'de bu sorun çıkmaz.)
- **ASC "Username/Password required"** → App Review'da "Sign-in required" kutusu kapatılmalı.
- **Watch App ID capability hatası** → `watchkitapp` ve `.complications` App ID'lerinde
  App Groups (+ Watch app'te Time Sensitive Notifications) Developer portal'da açık olmalı;
  aksi halde Xcode Cloud'un export adımı imzalama hatası verir.
