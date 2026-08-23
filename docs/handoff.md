# Handoff

## CURRENT TASK — 1.5 (8) hazır, 1.4'ün yayınlanması bekleniyor
**1.4 (7) App Review'da** (metadata + ASO alanları girildi, What's New yazıldı).
Kullanıcı kararı: 1.4 olduğu gibi çıkacak; **1.5 (8) kodu hazır ve doğrulandı**, 1.4
yayınlandıktan sonra kullanıcı arşivleyip gönderecek.

1.5'in içeriği (1.4'ü review ederken bulunan iki gerçek hata):
- **Kıble artık asla doğrulanmamış koordinattan çizilmiyor.** İl/ilçe seçicisi geocode
  başarısız olunca sessizce `39.0/35.0` (Kırşehir civarı) saklıyordu → kullanıcı uyarısız
  yanlış yöne yöneliyordu. Ayrıca konum hiç yokken açı 0'da kalıp **kuzeyi kıble**
  gösteriyordu. Koordinatlar opsiyonel yapıldı, placeholder kaldırıldı; izin varsa açı
  **gerçek GPS'ten** hesaplanıyor, hesaplanamıyorsa yön yerine konum izni isteniyor.
- **Drift uyarısına 25 km mesafe eşiği.** Yalnızca ilçe ID'si karşılaştırıldığı için,
  ilçe sınırına yakın oturan kullanıcı evindeyken uyarı alabiliyordu.

Gerekçeler `docs/decisions.md` (2026-08-24). Doğrulama: bağımsız hesaplanan kıble
açılarıyla karşılaştırıldı (Ankara canlı GPS 160° / beklenen 160.1; legacy 1.4 verisi
152° / beklenen 151.6), mesafe eşiği kontrol testiyle, 16/16 birim testi, iOS+watchOS
derlemesi.

**ASO baseline (24 Ağu 2026, 1.4 yayınlanmadan önce):** "ezan vakti" aramasında ~70. sıra.
1.4 çıktıktan 1-2 hafta sonra aynı aramalar tekrarlanıp karşılaştırılacak.

## ÖNCEKİ
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

**Pushlanmamış local commit'ler (main'de, origin'de yok):** `736dd66`'dan itibaren —
DEBUG-only test kancaları, growth özellikleri (rating/paylaş), kullanıcının bildirdiği 4
sorunun düzeltmesi, review sonrası iki ek düzeltme, 1.4 bump ve şema düzeltmesi.
Kullanıcı kararıyla toplu pushlanacak.

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

### Şema düzeltmesi (23 Ağu 2026)
Xcode'un şema seçicisinde **"Sekine" şeması kaybolmuştu** (yalnızca Watch/Complications/
Widget görünüyordu) — kullanıcı yanlışlıkla bir extension'ı arşivlemek üzereydi. Kök neden:
XcodeGen `.xcscheme` üretmiyordu, şemalar Xcode tarafından otomatik oluşturulup
gitignore'daki `xcuserdata`'da tutuluyordu ve `xcodegen generate` sonrası bayatlıyordu.
Aynı neden Xcode Cloud'da da vardı (CI "Catalog" adımı hep 3 şema buluyordu). Çözüm: dört
şema da `project.yml`'deki `schemes:` bloğunda tanımlandı → paylaşılan şema olarak
üretiliyor. `.xcodeproj` tamamen silinip sıfırdan üretilerek doğrulandı. Detay:
`docs/decisions.md`.

## DONE
Sürüm bazlı özet `PLAN.md`'de. Buraya yalnızca tekrar araştırılması pahalı olan bağlam:

- **Faz E4 (Apple Watch)** — Core kodu değişmeden watch hedefinde derlendi. Uygulama
  sırasında çözülen 3 gerçek sorun: `UNNotificationSound(named:)` watchOS'ta yok (sistem
  sesine düşülüyor), Swift 6 concurrency (nonisolated erişim), bildirim izni her açılışta
  isteniyordu (artık yalnızca onboarding'te). WatchConnectivity `xcrun simctl pair` ile
  uçtan uca doğrulandı. Watch app'in TAMAMI premium kilidinde (bilinçli tasarım) →
  ekran görüntüsü almak için `-uiTestForcePremium` gerekiyor.
- **Xcode Cloud CI** çalışır durumda (build 24 yeşil). Build 1'den 19'a kadar hiç yeşil
  build yoktu; Xcode Cloud hiç kullanılmıyordu, tüm gönderimler Xcode GUI'den elle
  yapılıyordu. `ci_scripts/ci_post_clone.sh` her çalışmada `xcodegen generate` + paket
  resolve yapıyor ve Xcode Cloud'un zorladığı `IDEPackageOnlyUseVersionsFromResolvedFile`/
  `IDEDisableAutomaticPackageResolution` defaults'larını temizliyor. Detay:
  `docs/decisions.md` (2026-08-20). **Kural: `project.yml`/`ci_scripts/` değişince
  push'tan önce `./scripts/verify-xcode-cloud.sh` çalıştır.**

## NEXT
1. 1.4 (7): Archive → Upload → ASC'de sürümü oluştur (What's New + ASO metadata) → Submit.
2. Yayından ~1 hafta sonra App Analytics → App Store Search verisine bak; ASO
   metadata'sının etkisini ölç, duruma göre Apple Search Ads'e başvurulup
   başvurulmayacağına karar ver.
3. Gerçek cihaz/TestFlight gerektiren doğrulamalar: uzun süreli bildirim + BG-refresh
   güvenilirliği, Watch bildirim dedup'ı, kıble pusulası.
4. Gelir zinciri (kod dışı): 20/B istisna belgesi + özel hesap gelince ASC'de IBAN güncelle.
5. (Opsiyonel) İstanbul dışı illerde eksik ilçe talebi gelirse il-bazlı doğrulayarak alias ekle.

## BLOCKERS
Yok.

## BEST AGENT NOW
Claude — ürün/veri kararı gerektiren işler sürüyor.

---

## Referans notları (sık aranan, tekrar araştırmaya gerek yok)

> Apple ID/Team, bundle ID'ler, gönderim adımları, mağaza metinleri ve geçmişte çözülen
> gönderim hataları → `docs/store-submission.md`.

**Repo görünürlüğü PUBLIC kalmalı:** Support URL + Privacy Policy URL repo'ya bağlı (ASC
gereksinimi); private yapılırsa App Store'daki linkler kırılır. Bilinçli karar.

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
