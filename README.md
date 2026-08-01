# Sekine — Namaz Vakti (iOS)

Sade, reklamsız, gizliliğe saygılı bir namaz vakti uygulaması. Türkiye / Diyanet
odaklı; her yaştan kullanıcı, özellikle yaşlılar için büyük ve anlaşılır arayüz.

## Neden Sekine?

Pazardaki namaz vakti uygulamalarının en çok şikayet aldığı noktalar, Sekine'nin
tasarım ilkeleri hâline geldi:

- **Bildirimler durmaz.** iOS'un 64-bildirim penceresi kayan zamanlayıcı (rolling
  scheduler) + arka plan yenileme + app açılışı tazelemesiyle sürekli doldurulur.
- **Sıfır reklam, sıfır takip.** Hiçbir reklam/analytics SDK'sı yok.
- **%100 çevrimdışı & gizli.** Vakitler ilk kurulumda bir kez indirilip cihazda
  saklanır; konumunuz cihazdan çıkmaz.
- **Diyanet uyumlu.** Vakit kaynağı Aladhan `method=13` (Diyanet); mimari
  kaynak-bağımsızdır, gerekirse Diyanet resmi API'sine geçilebilir (bkz.
  `docs/decisions.md`).
- **Widget.** Ana ekranda sonraki vakit + geri sayım.

## Teknoloji

- SwiftUI, iOS 17+, native.
- Bağımlılık: yalnızca `adhan-swift` (çevrimdışı fallback hesabı için).
- Proje dosyası **XcodeGen** ile üretilir (`project.yml` kaynaktır).

## Geliştirme

```bash
brew install xcodegen         # bir kez
xcodegen generate             # Sekine.xcodeproj üretir
open Sekine.xcodeproj
```

Komut satırından derleme/test:

```bash
xcodebuild -project Sekine.xcodeproj -scheme Sekine \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO build   # veya test
```

## Yol Haritası

- **v1** (bu sürüm): vakitler, geri sayım, aylık imsakiye, kıble, bildirimler, widget.
- **v1.1**: StoreKit 2 aboneliği → tam ezan (peşpeşe bildirim). Mimari hazır
  (`Core/Premium/PremiumGate.swift`).
- **Faz 2**: Android (Kotlin, ayrı repo), globalleşme, ayet paylaşımı, dini bulmacalar,
  Apple Watch.

## Lisans

MIT — bkz. `LICENSE`.
