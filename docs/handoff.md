# Handoff

## CURRENT TASK — 1.7 (10) ASC'de, incelemeye gönderilmeyi bekliyor
**29 Eyl 2026.** `integration/all-features` `main`'e alındı (Faz 1–3 kod işlerinin hepsi),
sürüm `project.yml`'de 1.7 (10). Kapsam ve gönderim öncesi kullanıcı adımları: `PLAN.md`.
Gerekçeler: `docs/decisions.md` (2026-09-23 → 09-27). Yol haritası:
`/Users/yusufgul/.claude/plans/sekinenin-app-store-analytics-immutable-firefly.md`.

**29 Eyl gecesi:** cihaz sandbox testi yapıldı (yıllık $2.99 + ömürlük paywall'da göründü); yıllık abonelik
ASC'de oluşturuldu (bkz. PLAN.md); 1.7 (10) `xcodebuild archive` + `-exportArchive` (method app-store-connect,
destination upload, automatic signing, `-allowProvisioningUpdates`) ile yüklendi — bu yöntem Xcode GUI'siz çalışıyor.
30 Eyl 00:10: build işlendi, ihracat beyanı 'None of the algorithms' (kullanıcı onayıyla), 1.7'ye bağlandı; iOS App 1.7 + Premium Yearly ASC 'Draft Submission'da. Kalan: Draft Submission panelinden Submit for Review (kullanıcı onayı). Not: sürüm 'Automatically release' — onaydan sonra kendiliğinden yayına çıkar.
Yayında olan son sürüm 1.6 (9). Bilinçli yapılmayanlar (kullanıcı kararı bekliyor):
çok aylık imsakiye (onaylı, sıradaki kod işi), Kur'an+meal (lisans), AI ezan (hesap/anahtar).

## DONE
Sürüm bazlı özet `PLAN.md`'de. Buraya yalnızca tekrar araştırılması pahalı olan bağlam:

- **Faz E4 (Apple Watch)** — Core kodu değişmeden watch hedefinde derlendi. Uygulama
  sırasında çözülen 3 gerçek sorun: `UNNotificationSound(named:)` watchOS'ta yok (sistem
  sesine düşülüyor), Swift 6 concurrency (nonisolated erişim), bildirim izni her açılışta
  isteniyordu (artık yalnızca onboarding'te). WatchConnectivity `xcrun simctl pair` ile
  uçtan uca doğrulandı. Watch app'in TAMAMI premium kilidinde (bilinçli tasarım) →
  ekran görüntüsü almak için `-uiTestForcePremium` gerekiyor.
- **Xcode Cloud CI** çalışır durumda; Build + Test kurulumu 24 Ağu 2026'da yeşil doğrulandı
  (ilk kez testler de CI'da koşuyor). Build 1'den 19'a kadar hiç yeşil
  build yoktu; Xcode Cloud hiç kullanılmıyordu, tüm gönderimler Xcode GUI'den elle
  yapılıyordu. `ci_scripts/ci_post_clone.sh` her çalışmada `xcodegen generate` + paket
  resolve yapıyor ve Xcode Cloud'un zorladığı `IDEPackageOnlyUseVersionsFromResolvedFile`/
  `IDEDisableAutomaticPackageResolution` defaults'larını temizliyor. Detay:
  `docs/decisions.md` (2026-08-20). **Kural: `project.yml`/`ci_scripts/` değişince
  push'tan önce `./scripts/verify-xcode-cloud.sh` çalıştır.**
  Workflow **Archive/export yapmıyor**, yalnızca Build + Test koşuyor (24 Ağu 2026 kararı,
  bkz. `docs/decisions.md`): export edilen üç dağıtım paketi hiç kullanılmıyordu ve
  imzalama yüzünden CI'ı sürekli kırmızı tutuyordu. Release arşivi Xcode'dan elle alınır.
  **Workflow'un güncel hâli** (ASC'de tutuluyor, repoda değil — sıfırlanırsa referans):
  · Test - iOS → Platform iOS, Scheme `Sekine`, Required to Pass, Test (Use Scheme Setting),
    Destination "Recommended iPhones" / Latest from Selected Xcode
  · Build - iOS → Platform iOS, Scheme `Sekine`, Build For "Any iOS Device"
  · Post-Actions: BOŞ (TestFlight/App Store dağıtımı yok — imzalama hatası buradan geliyordu)
  Tek `Sekine` şeması iPhone + Widget + Watch + komplikasyonları birlikte derler (Watch
  gömülü bağımlılık); ayrı watchOS action'a gerek yok.

## NEXT
0. **AI ezan (30 Eyl):** ElevenLabs Free planda (10k kredi) Music v2 ile 2 aday üretildi ("The Call of Hijaz", "Adhan in Hijaz Makam", elevenlabs.io/app/music/history). Ajan ses dinleyemez → kalite kararı kullanıcı + 3-5 kişilik panel. Free planda MUSIC İNDİRİLEMİYOR ve ticari kullanım yok (arayüz: "indirme ve ticari kullanım için upgrade"); gömmek için ücretli plan (Starter $6/ay) gerekir — kullanıcı satın alır. Onay çıkarsa: `ezan.caf` (≤30sn) + `ezan-full.m4a` → `Sekine/Resources/Audio/`, kod kapısı otomatik açılır.
1. Kullanıcı: sandbox satın alma/restore testi, ASC yıllık abonelik ürünü, yurtdışı vakit
   karşılaştırması → Archive → 1.7'yi Submit (bkz. `PLAN.md`).
2. **Çok-ay/yıllık imsakiye:** yakın 32 gün Diyanet-birebir + ötesi çevrimiçi "yaklaşık"
   (etiketli). Önce kaynak kararı (Aladhan method=13 vs Awqat Salah+proxy) ve ölçümü genişlet
   (çok şehir/mevsim/yurt dışı); **iftar için güvenlik payı şart**. Bkz. decisions 2026-09-27.
3. Kur'an+meal: kullanıcıyla tartışma (seçenekler decisions 2026-09-27; öneri: önce resmî
   siteye bağlantı + Diyanet izin yazışması). AI ezan: kullanıcı ElevenLabs anahtarını hazırlayınca.
4. Kullanıcı (kod dışı): In-App Events (`docs/in-app-events.md`, tarih doğrulama), Featuring
   (Aralık başına kadar), Search Ads, diaspora keyword yerelleştirmesi.
5. 2–3 hafta sonra ASC Analytics tekrar ölçüm.
6. Gerçek cihaz: uzun süreli bildirim + BG-refresh, Watch dedup, kıble pusulası.
7. Kalan kozmetik StoreKit riskleri #1/#2/#3/#5 (düşük öncelik).

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

**ASC Paid Applications Agreement + banka:** imzalandı (20 Ağu 2026); geçici hesap yerine
20/B istisna belgesiyle açılan özel ticari hesap ASC'ye eklendi (29 Eyl 2026). Kapandı.

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
