# Kararlar (ADR-lite)

> Yeni girdi en üste. Geçmiş girdiler geriye dönük düzenlenmez.

## 2026-08-20 — Xcode Cloud + XcodeGen: ci_scripts/ci_post_clone.sh zorunlu, push öncesi scripts/verify-xcode-cloud.sh
**Sorun:** `Sekine.xcodeproj/` bilinçli olarak gitignore'da (XcodeGen üretimi, kaynak
`project.yml`). Xcode Cloud repoyu clone'layıp doğrudan `Sekine.xcodeproj` arıyor → build 19
"Project Sekine.xcodeproj does not exist at the root of the repository" ile fail etti.
Düzeltilince (post-clone'da `xcodegen generate`), ikinci katman sorun çıktı: Xcode Cloud'un
CI ortamı `com.apple.dt.Xcode` defaults'ında `IDEPackageOnlyUseVersionsFromResolvedFile` ve
`IDEDisableAutomaticPackageResolution`'ı zorunlu kılıyor — bu, HER xcodebuild çağrısının
(bizim post-clone'daki dahil) önceden var olan bir `Package.resolved` istemesine sebep
oluyor; ama proje her seferinde SIFIRDAN üretildiğinden o dosya hiç var olamıyor (tavuk-yumurta).
**Karar:** `ci_scripts/ci_post_clone.sh` şu sırayla çalışır: (1) yukarıdaki iki `defaults`
anahtarını sil, (2) xcodegen kurulu değilse brew ile kur, (3) `xcodegen generate`,
(4) `xcodebuild -resolvePackageDependencies -project Sekine.xcodeproj` (scheme belirtmeye
gerek yok — xcodegen hiç `.xcscheme` dosyası yazmıyor, xcodebuild target'lardan örtük
scheme listesi çıkarıyor, `-scheme` verilirse CI'da bazı yollarda patlıyor).
**Tekrarını önleme:** `scripts/verify-xcode-cloud.sh` eklendi — `Sekine.xcodeproj`'u silip
gerçek `ci_post_clone.sh`'ı çalıştırıp `CODE_SIGNING_ALLOWED=NO` ile build alır (imzalama
yerel/CI'da farklı olduğundan archive değil build; App Groups/Time Sensitive Notifications
entitlement'ları yerel development profilinde yok). `project.yml` veya `ci_scripts/`
değişince push'tan ÖNCE bu script çalıştırılmalı — Xcode Cloud'un push→bekle→log-oku
döngüsü yerine 30 saniyede yerel doğrulama.
**Elenen alternatifler:** (a) `Sekine.xcodeproj`'u gitignore'dan çıkarıp commit etmek —
XcodeGen'in "tek kaynak project.yml" ilkesini bozar, iki dosya sürüklenme riski yaratır,
reddedildi. (b) `-onlyUsePackageVersionsFromResolvedFile NO` gibi xcodebuild flag'i geçmek
— bu flag argüman almayan bir "presence" anahtarı, `NO` değeri "Unknown build action 'NO'"
hatası veriyor; zaten mesele flag'in bizim geçtiğimiz bir şey değil, Xcode Cloud'un
defaults seviyesinde zorladığı bir ayar olması.

## 2026-08-01 — Vakit kaynağı: Aladhan method=13, kaynak-bağımsız mimari
**Karar:** v1, vakitleri Aladhan API `method=13` (Diyanet İşleri Başkanlığı) ile bir kez
indirip cihazda cache'ler. Veri katmanı `PrayerTimeProvider` protokolü ile soyutlandı.
**Neden:** Kimlik bilgisi/kayıt gerektirmez, stabil, çevrimdışı çalışmayı destekler,
gizlilik korunur (tek çağrı, tracking yok).
**Risk:** Aladhan bu metodu "(experimental)" olarak işaretliyor; Diyanet'in resmi
yayınlanan tablosundan özellikle İmsak/Fajr'da birkaç dakika sapabilir. Türk kullanıcı
bunu fark eder → düşük yıldız riski.
**Azaltma:** Submit öncesi İstanbul/Ankara/İzmir için Diyanet resmi vakitleriyle
karşılaştırma ZORUNLU. Sistematik sapma varsa aynı protokolü uygulayan Diyanet resmi
(awqatsalah) sağlayıcısı eklenecek — uygulamanın geri kalanı değişmez.
**Elenen alternatifler:** (a) Tamamen lokal hesap (adhan-swift) → daha da sapar, sadece
fallback yapıldı. (b) vakit.vercel.app Diyanet API'si → endpoint'leri kapalı/değişmiş.

## 2026-08-01 — Native SwiftUI (cross-platform değil)
**Karar:** iOS native SwiftUI; Android Faz 2'de ayrı Kotlin.
**Neden:** Uygulamanın çekirdek değeri bildirim güvenilirliği + ses kontrolü — iOS'un en
kısıtlı alanı. Native, UNUserNotificationCenter/BGTask üzerinde maksimum kontrol verir.
Cross-platform framework tam bu eksende zayıf.
**Elenen:** Expo/React Native (tek kod tabanı avantajı, ama kritik eksende kontrol kaybı).

## 2026-08-01 — v1 ücretsiz + reklamsız; abonelik v1.1
**Karar:** v1'de IAP yok; `PremiumGate` her zaman false. Tam ezan (peşpeşe bildirim)
aboneliği v1.1.
**Neden:** En hızlı store yolu (StoreKit/vergi/IAP review karmaşası v1'i geciktirmesin).
Reklamsızlık + gizlilik zaten pazarda öne çıkarır (rakiplerin en büyük şikayeti reklam).

## 2026-08-01 — Bildirim güvenilirliği: çok katmanlı rolling scheduler
**Karar:** iOS 64-bildirim sınırının altında (60) kayan pencere; app açılışı + BGAppRefresh
+ willPresent üç tetikleyiciyle tazelenir; veri cache'ten okunur (network gerektirmez).
**Neden:** Rakiplerin 1 numaralı şikayeti "bildirimler bir süre sonra duruyor". Tek
tetikleyici (ör. sadece BGRefresh) iOS'ta garanti değil; katmanlı yaklaşım güvenilir kılar.

## 2026-08-01 — Ses: orijinal chime; tam ezan yok (v1)
**Karar:** Telifsiz orijinal `chime.caf` (2.5 sn) üretildi; "Kısa Ezan" seçeneği v1'den
çıkarıldı.
**Neden:** Kaliteli/telifsiz tam ezan sesi v1'de sağlanamaz; sahte/düşük kalite ses
yerine dürüst kısa bildirim. Tam ezan v1.1 premium.
