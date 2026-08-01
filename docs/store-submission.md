# App Store Gönderim Rehberi

## 0. SUBMIT ÖNCESİ ZORUNLU — Diyanet doğruluk doğrulaması
En büyük 1-yıldız riski budur. Göndermeden önce:
1. Uygulamada İstanbul, Ankara, İzmir için vakitleri aç.
2. Aynı gün için Diyanet resmi vakitleriyle karşılaştır:
   https://namazvakti.diyanet.gov.tr (ilgili ilçeyi seç).
3. Özellikle **İmsak** ve **Yatsı**'ya bak (en çok sapan vakitler).
4. Sapma ≤1 dk ise kabul; >1-2 dk ise `PrayerTimeProvider`'a Diyanet resmi
   (awqatsalah.diyanet.gov.tr) sağlayıcısı ekle — `PrayerTimeStore.primary`'yi değiştir,
   başka yer değişmez. Kayıt/JWT gerekir (ücretsiz).

## 1. Xcode signing (kullanıcı)
- `project.yml` → `DEVELOPMENT_TEAM` boş. Xcode'da hedefi seç → Signing & Capabilities →
  Team'i seç (App group provisioning otomatik oluşur).
- Bundle ID'ler: `com.sekineapp.sekine` (app), `.widget`, `.tests`. App Store Connect'te
  `com.sekineapp.sekine` benzersiz olmalı; değilse project.yml'de değiştir + `xcodegen generate`.
- App Group `group.com.sekineapp.sekine`'i Apple Developer portal'da kaydet.

## 2. App Store Connect kaydı
- **İsim:** "Sekine" (müsaitlik kontrolü: App Store Connect'te yeni app oluştururken görürsün;
  doluysa "Sekine - Namaz Vakti" dene).
- **Alt başlık:** Reklamsız, gizli namaz vakti
- **Kategori:** Yaşam Tarzı (veya Referans)
- **Yaş sınırı:** 4+

## 3. Gizlilik "Nutrition Label" (App Privacy)
- **Veri toplama: YOK.** "Data Not Collected" seç. (Backend yok, analytics yok, reklam yok.)
- Konum yalnızca cihazda kullanılır, toplanmaz/gönderilmez → beyan gerekmez.
- Not: Aladhan API'ye yalnızca koordinat + tarih gider, kullanıcı kimliği gitmez. Bu bir
  3rd-party servistir; istersen gizlilik metninde belirt (zorunlu değil, kişisel veri değil).

## 4. Mağaza açıklaması (paste'e hazır)

**Kısa:**
> Sekine, reklamsız ve gizliliğe saygılı bir namaz vakti uygulamasıdır. Diyanet'e uygun
> vakitler, güvenilir bildirimler, sade ve büyük bir arayüz.

**Uzun:**
> Sekine; namaz vakitlerini sade, huzurlu ve güvenilir biçimde sunar.
>
> • Reklamsız — hiçbir reklam, hiçbir dikkat dağıtıcı yok.
> • Gizli — verileriniz cihazınızdan çıkmaz, hiçbir takip yok.
> • Diyanet uyumlu — Türkiye vakitleri, çevrimdışı çalışır.
> • Güvenilir bildirimler — vakit bildirimleri düzenli yenilenir, susmaz.
> • Ana ekran widget'ı — sonraki vakit ve geri sayım.
> • Kıble pusulası.
> • Her yaşa uygun — büyük, net, anlaşılır tasarım.
>
> Reklam yok. Abonelik zorunluluğu yok. Sadece namaz vakitleri.

**Anahtar kelimeler:** namaz,ezan,vakit,imsak,diyanet,kıble,namaz vakti,ezan vakti,imsakiye,dua

## 5. Ekran görüntüleri
- Gerekli: 6.9" (iPhone 17 Pro Max) — App Store Connect'in istediği boyut.
- Simülatörde (iPhone 17 Pro Max) çalıştırıp yakala:
  `xcrun simctl io booted screenshot ekran1.png`
- Öneri: Onboarding, Home (geri sayım), Aylık, Kıble ekranları.

## 6. Derleme & yükleme
- Xcode → Product → Archive → Distribute App → App Store Connect.
- Veya `xcodebuild archive` + `xcrun altool`/Transporter.
- TestFlight'ta kendinde bir dene, sonra "Submit for Review".

## 7. Review notları (App Review'a)
- Uygulama tamamen ücretsiz, IAP yok, hesap gerektirmez.
- Konum izni: yalnızca namaz vakti hesabı için, cihazda kullanılır.
