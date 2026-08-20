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
- **Diyanet uyumlu.** Vakit kaynağı birebir Diyanet (ezanvakti/namazvakti.diyanet.gov.tr
  aynası), yedek Aladhan `method=13`; mimari kaynak-bağımsızdır (bkz. `docs/decisions.md`).
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

- **v1** (yayında): vakitler, geri sayım, aylık imsakiye, kıble, bildirimler, widget.
- **Faz 2** (neredeyse tamam): Ömürlük Premium + Bağış (StoreKit 2) — tam ezan, premium
  temalar, çoklu konum; ücretsiz Zikir sekmesi; Apple Watch companion app.
- **Faz 3**: Android (Kotlin, ayrı repo), globalleşme, ayet paylaşımı, dini içerik.

## Destek & Gizlilik

- **Destek:** Soru ve geri bildirim için gull.yusuff@gmail.com
- **Gizlilik Politikası:** [PRIVACY.md](PRIVACY.md) — Sekine hiçbir kişisel veri toplamaz,
  saklamaz veya paylaşmaz.

## Lisans

MIT — bkz. `LICENSE`.
