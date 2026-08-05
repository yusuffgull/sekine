# Handoff

## CURRENT TASK — App Store gönderimi (build 2 YÜKLENDİ, review'a gönderme aşaması)
Build 2 (iPhone-only fix'li) App Store Connect'e başarıyla yüklendi. Apple "processing"
yapıyor. Kalan: processing bitince build'i sürüme ekle + zorunlu bölümleri (App Privacy,
Age Rating, Pricing) tamamla + Submit for Review.
Apple ID: 6796900944. Signing Team: 33L468BTR2. Repo PUBLIC.
Metadata (Name "Sekine - Namaz Vakti", subtitle, description, keywords, support URL) girildi.
90474 hatası çözüldü → TARGETED_DEVICE_FAMILY=1 (app+widget iPhone-only), build 2.

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

## NEXT (hepsi kullanıcı — interaktif Apple işlemleri)
1. Xcode'a Apple Developer hesabını ekle (Xcode → Settings → Accounts). Makinede henüz
   imzalama kimliği YOK.
2. `open Sekine.xcodeproj` → Sekine + SekineWidget hedeflerinde Team seç (Signing &
   Capabilities). App Group `group.com.sekineapp.sekine` otomatik provision olur.
3. App Store Connect'te uygulama oluştur ("Sekine" müsait değilse "Sekine - Namaz Vakti").
   Gizlilik = Data Not Collected. Metinler `docs/store-submission.md`'de hazır.
4. Product → Archive → Distribute → App Store Connect. TestFlight → Submit for Review.

## BLOCKERS
Kullanıcının Apple Developer hesabı Xcode'a girilmeli (şu an 0 imzalama kimliği). Bundle ID
benzersizliği ASC'de doğrulanmalı.

## BEST AGENT NOW
Claude — release/submission hazırlığı ve Diyanet doğruluk doğrulaması karar gerektirir.
