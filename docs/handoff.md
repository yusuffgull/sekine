# Handoff

## CURRENT TASK
**1.4 (7) arşivlenmeyi bekliyor.** 1.3 (6) — Premium/IAP + Apple Watch içeren sürüm —
Apple review'ından geçti ve **yayında** (Ready for Distribution, 23 Ağu 2026). Yayına
çıkmış bir versiyona yeni build eklenemediği için sonraki tüm değişiklikler **1.4**'e
alındı (`MARKETING_VERSION` 1.4, build 7; gömülü Watch app'in sürümü de 1.4 (7) olarak
doğrulandı — Apple eşleşmesini şart koşuyor).

1.4'ün içeriği (yayındaki 1.3'te YOK): growth özellikleri (rating isteme,
Değerlendir/Paylaş) + kullanıcının bildirdiği 4 sorunun düzeltmesi (konum otomatik
güncelleme, Ayarlar'da GPS butonu, Cuma/ayet-dua saati açıklamaları, bağış butonu race)
+ review'da bulunan 2 ek düzeltme.

4 IAP ürünü 1.3 ile birlikte onaylandı → 1.4'te tekrar iliştirmeye gerek yok.
Kalan: Xcode'dan Archive → Upload, ASC'de 1.4 sürümünü oluştur (What's New + ASO
metadata) → **Submit for Review**.

**ASO metadata (ASC'de elle girilecek, build'den bağımsız):** App Name
`Sekine: Ezan ve Namaz Vakti`, Subtitle `Kıble, İmsakiye, Ezan Saatleri`, Keywords
`ezan,namaz,vakit,imsak,kıble,diyanet,imsakiye,sabah,öğle,ikindi,akşam,yatsı,dua,zikir,hicri,takvim`.
Gerekçe: arama ağırlığı App Name > Subtitle > Keywords; "ezan" daha önce yalnızca
Keywords'teydi. Description aramada kullanılmaz.

**Pushlanmamış local commit'ler (main'de, origin'de yok):** `736dd66`..`d52d5e8` —
DEBUG-only test kancaları, growth özellikleri (rating/paylaş), kullanıcının bildirdiği 4
sorunun düzeltmesi ve review sonrası iki ek düzeltme. Kullanıcı kararıyla bir sonraki
geliştirmeyle birlikte pushlanacak.

### Review sonucu (23 Ağu 2026) — backward compatibility TEMİZ
Pushlanmamış 6 commit tam diff okunarak review edildi. Yeni `UserDefaults` anahtarları
nil-güvenli okunuyor, mevcut anahtarların anlamı değişmedi, `SavedLocation`/`PrayerCache`
modelleri aynı → mevcut kullanıcıda veri kaybı/çökme riski yok. Widget hedefi değişen
dosyaların hiçbirini almıyor; watch hedefi alıyor ve watchOS derlemesi doğrulandı.
Testler (12/12) değişen tipleri hiç kurmuyor, hepsi geçiyor. DEBUG kancaları `#if DEBUG`
içinde → Release binary'ye girmiyor. Konum izin metinleri yeni foreground kontrolünü
zaten doğru tarif ediyor.

Review'da bulunan **2 gerçek hata düzeltildi** (`d52d5e8`): (1) rating diyalogu konum
uyarısını yutuyordu — ask artık bootstrap'ı bekleyip öneri varken atlıyor ve sürüm
kapısını yakmıyor; ayrıca `RootView`'a eksik `import StoreKit` eklendi. (2) Konum önerisi
reddedilince hatırlanmıyordu, 24 saatte bir tekrar soruyordu — `declinedLocationDistrictID`
kalıcı saklanıyor, konum elle değişince sıfırlanıyor.

**Bilinen, kasıtlı olarak ertelenen:** 4 ayrı `DiyanetDirectory` örneği var (SekineApp,
SettingsView, OnboardingView, LocationSearchSheet), her biri kendi bellek cache'iyle
il/ilçe listesini ayrı ayrı indirebiliyor. Yayın öncesi çalışan koda dokunmamak için
şimdi yapılmadı; tek örneği `.environmentObject` ile paylaştırmak temiz bir iyileştirme.

## DONE
- **v1** yayında: native SwiftUI, Diyanet birebir vakit kaynağı (DiyanetProvider), il/ilçe
  konum, RollingScheduler bildirimleri, WidgetKit. **v1.1** gönderildi (UX düzeltmeleri).
- **Faz 1.2/1.3** (güvenilirlik, hicri/kıble saati, ek hatırlatmalar) kod tamam.
- **Faz 2** (Ömürlük Premium + Bağış, StoreKit 2, backend'siz) neredeyse tamam: StoreKit
  altyapısı, tam ezan, premium temalar/ikon, ücretsiz Zikir sekmesi, çoklu konum, vakit-başına
  ses, premium widget accent — hepsi push'landı.
- **Faz E4 (Apple Watch)** — `SekineWatch` + `SekineWatchComplications` hedefleri, paylaşılan
  Core kod değişikliksiz derlendi, watch-özel ekranlar (Onboarding/Home/Qibla/Paywall/Tesbih),
  gerçek komplikasyon view'ları, çift yönlü WatchConnectivity — `xcrun simctl pair` ile
  iPhone→Watch context transferi ekran görüntüsü kanıtlı doğrulandı. 3 gerçek sorun çözüldü:
  `UNNotificationSound(named:)` watchOS'ta yok (sistem sesine düşülüyor), Swift 6 concurrency
  (nonisolated erişim), bildirim izni her açılışta isteniyordu (artık yalnızca onboarding'te).
- **Xcode Cloud CI** ilk kez çalışır hale getiriliyor (20 Ağu 2026) — build 1'den beri hiç
  yeşil build almamıştı (Xcode Cloud hiç kullanılmıyordu, tüm gönderimler Xcode GUI'den elle
  yapılıyordu). `ci_scripts/ci_post_clone.sh` eklendi: `Sekine.xcodeproj` gitignore'da olduğu
  için (XcodeGen üretimi) her CI çalışmasında `xcodegen generate` + paket resolve gerekiyor;
  Xcode Cloud'un zorladığı `IDEPackageOnlyUseVersionsFromResolvedFile`/
  `IDEDisableAutomaticPackageResolution` defaults'ları da temizleniyor. Detay: `docs/decisions.md`
  (2026-08-20). **Kural: `project.yml`/`ci_scripts/` değişince push'tan önce
  `./scripts/verify-xcode-cloud.sh` çalıştır.**

## NEXT
1. Xcode Cloud'da yeni build tetikleyip yeşil geçtiğini doğrula.
2. Faz E4 kalanı: gerçek dedup testi (iki cihaz aynı anda bildirim → tek bildirim) ve
   premium ekranların görsel doğrulaması — TestFlight/gerçek cihaz gerektiriyor.
3. Gelir zinciri (kod dışı, kullanıcı takip ediyor): 20/B istisna belgesi + özel hesap
   gelince ASC'de IBAN güncelle; IAP ürün ID'leri ASC'de tanımlanabilir (bağımsız, hemen
   yapılabilir); ezan ses dosyaları ERTELENDİ (lisans araştırması durduruldu, kod gate'i hazır).
4. (Opsiyonel) İstanbul dışı illerde eksik ilçe talebi gelirse il-bazlı doğrulayarak alias ekle.

## BLOCKERS
Yok.

## BEST AGENT NOW
Claude — ürün/veri kararı gerektiren işler sürüyor.

---

## Referans notları (sık aranan, tekrar araştırmaya gerek yok)

**Repo görünürlüğü PUBLIC kalmalı:** Support URL + Privacy Policy URL repo'ya bağlı (ASC
gereksinimi); private yapılırsa App Store'daki linkler kırılır. Bilinçli karar.

**Apple ID:** 6796900944. **Team:** 33L468BTR2.

**Gönderim sırasında çözülen sorunlar:**
- 90474 (iPad orientation) → `TARGETED_DEVICE_FAMILY=1` her hedefte ayrı ayrı yazılmalı
  (XcodeGen proje-base ayarı target seviyesini ezmiyor).
- codesign "resource fork/detritus" → DerivedData'yı iCloud'lu `~/Documents` dışına ver.
- ASC "Username/Password required" → App Review'da "Sign-in required" kutusu kapatılmalı.
- Xcode GUI varsayılan DerivedData (`~/Library`) kullanır → iCloud xattr sorunu yaşanmaz;
  CLI'dan device build alırken `-derivedDataPath`'i iCloud'lu dizin dışına ver.

**AB erişilebilirliği:** 27 AB ülkesinde "Cannot Sell" idi (DSA Trader Status eksikti) →
kullanıcı "non-trader" seçti, global erişilebilirlik açıldı, İspanya'dan test indirmesiyle
doğrulandı (20 Ağu 2026). Kapandı.

**ASC Paid Applications Agreement:** imzalandı (20 Ağu 2026), geçici/başka-iş banka
hesabıyla — 20/B istisna belgesi + özel hesap gelince IBAN güncellenecek. Artık gelir
zincirinin önünde engel değil.

**Ezan ses dosyaları — ERTELENDİ:** CC0 adaylar bulundu (Madinah Fajr Azan - Sheikh Faisal
Numan, archive.org; Beautiful adhan.ogg, Wikimedia) ama "makam-bazlı 5 ayrı vakit" seti
(İlhan Tok / Abc Müzik) ticari lisans gerektiriyor. Gerekirse: `ezan.caf` (≤30sn bildirim
tonu) + `ezan-full.m4a` (in-app tam ezan) → `Sekine/Resources/Audio/`; kod dosyalar eklenince
otomatik aktifleşir (gate açık, dosya yoksa özellik sessizce pasif).

**İl/ilçe verisi:** kaynak ezanvakti.emushaf.net (Diyanet aynası), bazı isimler ASCII-hasarlı
ve İstanbul'da ~20 ilçe eksik (merkez 9541 altında veriliyor). Çözüm:
`Sekine/Core/Location/LocationOverrides.json` — 434 ad düzeltmesi + İstanbul ilçe alias'ları
(aynı IlceID → aynı vakit, güvenli). Bilinçli karar: diğer illerde toptan ilçe eklenmedi
(Antalya/Muğla gibi coğrafi geniş illerde merkeze bağlamak yanlış vakit riski taşır) — talep
gelirse il-bazlı doğrulanarak eklenmeli.
