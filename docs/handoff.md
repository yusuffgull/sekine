# Handoff

## CURRENT TASK — Faz 1.2 kodu tamam, CİHAZ TESTİ bekliyor (14 Ağustos 2026)
v1.1 App Store review'da (build 1.1(4), push'landı). Faz 1.2 (güvenilirlik+tamamlama)
KODU main'de tamamlandı, build+10/10 test+simülatör görsel doğrulandı:
- Time-Sensitive entitlement (Odak/Uyku/DND deler), kilit ekranı/StandBy widget'ları
  (circular/rectangular/inline), Hicri tarih (Home), Kıble saati (Qibla) — Diyanet verisi.
Sıradaki: KULLANICI gerçek cihazda test eder (bildirim güvenilirliği, kilit ekranı widget,
kıble pusulası). Testler geçince v1.2/build5 bump → v1.1 onaylandıktan sonra Submit.
Faz 1.2 henüz PUSH EDİLMEDİ (reliability+hicri/qibla merge'leri local main'de).

### v1.1 (build 4) — REVIEW'DA, push'landı:

### Bu turda yapılanlar (hepsi build+test doğrulandı, 10/10 test, simülatör görsel):
1. Bildirim metinleri: tüm vakitlere tutarlı temenni; Güneş bildirimi zaten kapalıydı
   (isNotifiable=false), ölü metin temizlendi.
2. Onboarding "ilçe bulunamadı" hatasından "Diyanet" kelimesi çıkarıldı.
3. Yazı boyutu artık TÜM ekranlarda: Home/Qibla zaten SekineFont; köke DynamicTypeSize
   (Settings/Onboarding/Search), Monthly sabit hücreler çarpan + lineLimit(1)+
   minimumScaleFactor (XL'de satır atlamasın). DEBUG hook: -uiTestFontScale.
4. Aylık: konum varsa OTOMATİK yüklenir; ay gezinme yüklü veriyle sınırlı (chevron
   disable); "ana ekrandan yükleyin" mesajı kaldırıldı, net boş-durum kondu.
5. Widget tanıtımı: Onboarding'de 4. vaat satırı + Ayarlar'da "Widget" bölümü (kurulum
   yönergesi).
6. **İl/ilçe verisi (önemli):** kaynak = ezanvakti.emushaf.net (Diyanet aynası). Aynada
   bazı isimler ASCII-hasarlı (Arnavutkoy) ve İstanbul'da ~20 idari ilçe yok (Üsküdar,
   Ataşehir…) çünkü Diyanet onları merkez İstanbul (9541) altında veriyor.
   Çözüm: bundle'lı `Sekine/Core/Location/LocationOverrides.json` → 434 GÖRÜNEN-ad
   düzeltmesi (aynı IlceID → aynı vakit, kanıtlanabilir güvenli) + İstanbul eksik
   ilçeleri 9541'e alias. Üretim scripti: emushaf ↔ yetkili il/ilçe (sh4dowb gist)
   normalize-eşleştirme; her fix orijinalle AYNI normalize kimliğine sahip.
   KARAR (kullanıcı onayı): toptan "tüm illere ilçe ekleme" YAPILMADI — Antalya/Muğla
   gibi coğrafi geniş illerde eksik ilçeyi merkeze bağlamak yanlış vakit riski taşır.
   Diğer illerde eksik ilçe talebi gelirse il-bazlı doğrulanarak eklenmeli.

### Faz 1 gönderim referansı (App Store):
Apple ID: 6796900944. Team: 33L468BTR2. Repo PUBLIC.

### Gönderim sırasında çözülen sorunlar (ileride tekrarında referans):
- 90474 (iPad orientation) → TARGETED_DEVICE_FAMILY=1 her hedefte (XcodeGen proje base'i
  target ayarını ezmiyor, TARGET seviyesine yazılmalı). Build 2.
- codesign "resource fork/detritus" → DerivedData'yı iCloud'lu ~/Documents DIŞINA ver.
- ASC "Username/Password required" → App Review'da "Sign-in required" kutusu kapatılmalı.
- İkon: even-odd hilal "çift hilal" görünüyordu → clip-ile-tek-hilal C3 konsepti, build 3.

### Sonraki (kullanıcı isterse):
- Faz 1.1: StoreKit 2 aboneliği + tam ezan (peşpeşe bildirim). PremiumGate hazır.
- Faz 2: Android (Kotlin), globalleşme, ayet paylaşımı, dini bulmacalar.

### ASC'de kaldığı yer — devam adımları (kullanıcı, interaktif):
1. App Information: Subtitle "Reklamsız, gizli namaz vakti"; Category Lifestyle (+Reference).
2. 1.0 sürüm sayfası: Description + Keywords (docs/store-submission.md'de hazır),
   Support URL = https://github.com/yusuffgull/sekine
3. Screenshots (6.9"): store/screenshots/ içindeki 5 PNG.
4. App Privacy = Data Not Collected · Pricing = Free · Age Rating = 4+.
5. Xcode: hedef "Any iOS Device" → Product → Archive → Distribute → App Store Connect →
   Upload. İşlenince sürüme build ekle → Submit for Review.
   NOT: Xcode GUI varsayılan DerivedData (~/Library) kullanır → iCloud xattr sorunu YOK.
   (CLI'dan device build yaparken -derivedDataPath'i iCloud'lu Documents DIŞINA ver.)

### Açık işler:
- Privacy Policy URL Apple ileride isteyebilir → repo'ya PRIVACY.md eklenebilir (yapılmadı).
- Ödemeli Apple Developer Program üyeliği şart (Distribute'te App Store yoksa sebebi bu).

## DONE
- Native SwiftUI (iOS 17+) tam uygulama: Onboarding, Home (canlı geri sayım), Aylık
  imsakiye, Kıble, Ayarlar, WidgetKit widget. 5 ekran da simülatörde görsel doğrulandı.
- **Vakit kaynağı = birebir Diyanet** (DiyanetProvider, ezanvakti/namazvakti.diyanet.gov.tr
  mirror, il/ilçe ID bazlı). Doğrulama: Aladhan method=13 Akşam/Yatsı'da 1-2 dk erkendi →
  Diyanet resmi veriye geçildi. Zincir: Diyanet → Aladhan → lokal (adhan-swift).
- Konum: il/ilçe picker + GPS→ilçe eşleştirme. RollingScheduler (64-pencere) + 3 tetikleyici.
- Reklamsız, backend'siz, tracking'siz. İkon + orijinal chime.caf.
- `xcodebuild build` başarılı; 9/9 unit test geçti. GitHub'a push edildi (private).
- App Store 6.9" ekran görüntüleri: `store/screenshots/` (1320x2868, 5 adet).

## NEXT
1. v1.1 UX düzeltmelerini **push et** (kullanıcı onayı bekleniyor; şu an sadece local main'de).
2. Yeni gönderim kararı verilince: project.yml'de MARKETING_VERSION 1.1 + CURRENT_PROJECT_VERSION 4,
   `xcodegen generate`, Archive → Distribute → Submit for Review.
3. (Opsiyonel) İstanbul dışı illerde eksik ilçe talebi gelirse il-bazlı doğrulayarak alias ekle.

## BLOCKERS
Yok (push onayı hariç).

## BEST AGENT NOW
Claude — ürün/veri kararı gerektiren işler sürüyor.
