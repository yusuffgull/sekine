# Handoff

## CURRENT TASK
v1 kod-tamam, GitHub'a push edildi, Diyanet doğruluğu çözüldü, App Store ekran görüntüleri
hazır. Kalan TEK iş: App Store gönderimi — tamamı kullanıcının Apple hesabıyla interaktif
yapılacak adımlar (Xcode'a Apple ID girişi, team, archive, ASC listing, submit).

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
