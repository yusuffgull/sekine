# Ramazan 2027 hazırlık planı (hedef: 15 Ocak'ta mağazada, Ramazan ≈ 8 Şubat 2027)

Amaç: Ramazan'da "iftar/sahur saatine en güvenilir bakılan uygulama" olmak. Mevcut: Ramazan sayacı
(`RamadanInfo`/`RamadanCard`), oruç takibi, iftar Live Activity, yaklaşık takvim. Eksikler aşağıda.
Kural: dini veri sessizce yanlış olmaz (bkz. memory sekine-religious-data-correctness); nazik bildirimler
default AÇIK, Focus-delen opt-in.

## Boşluklar (kod incelemesi, 17 Eki 2026)
1. **Sahur/iftar bildirimi yok.** `RollingScheduler` yalnızca vakit + ön hatırlatma + Cuma + kandil + ayet
   üretiyor. Ramazan'ın en değerli özelliği eksik.
2. **Ramazan widget'ı yok.** `SekineWidget` vakit widget'ı + Live Activity; sahur/iftar geri sayım widget'ı
   ve Watch komplikasyonu yok.
3. **Hicri veri yalnızca Diyanet kaynağında.** Yurtdışı/Aladhan/yerel fallback'te `hicriMonth == nil` →
   Ramazan modu sessizce kapalı (diaspora = hedef kitlenin büyük kısmı).
4. **Ramazan imsakiyesi** (30 gün sahur/iftar tablosu + paylaşım kartı) ayrı bir görünüm olarak yok;
   `MonthlyView` genel.
5. Ramazan öncesi geri sayım yalnızca yüklü pencere (~32 gün) içinde çalışır.
6. Mağaza: Ramazan ASO, In-App Event'ler, ekran görüntüleri, 1.9 kaydı (kullanıcı ASC girişi gerekli).

## Teslimat sırası (rev.2 — VISION RET sonrası, 17 Eki 2026)
Her adım ayrı branch; T3'ler NATASHA + VISION. Sıra bağımlılıktan gelir.

- **R0 — Hicri güven modeli** (T3): `PrayerDay.hicriMonth/hicriDay` = "Diyanet kesin" anlamında KALIR,
  tahmini veri oraya yazılmaz. Ayrı `HijriEstimate(month, day, source, confidence)` (Umm al-Qura,
  `Calendar(.islamicUmmAlQura)`). Tahmin; kandil/bayram bildirimlerini, oruç takibini ve paylaşım kartını
  ASLA kesinmiş gibi tetiklemez. Sınır günlerinde (ay başı/sonu ±1) kesin sahur/iftar bildirimi yok;
  kullanıcıya "Ramazan başladı mı?" düzeltmesi sunulur, konum+hicri yıl bazında saklanır; Diyanet verisi
  gelince tahmini bildirimler kaldırılıp yeniden planlanır.
- **R1 — Bütçe/kimlik tahsisçisi** (T3): `buildDesiredItems`'ta önce öncelikli, ≤60 elemanlı NİHAİ küme
  seçilir, sonra reconciliation (budget aşımında sessiz `break` yok). Öncelik: ana vakit > sahur/iftar >
  ön hatırlatma > ayet. Testler: 60/74 örneği, düşenlerin `deferred` sayılması.
- **R2 — Sahur & iftar bildirimleri** (T3): çakışan mevcut bildirimi (İmsak/Akşam ana veya ön hatırlatma)
  Ramazan metniyle DÖNÜŞTÜRÜR; yalnızca eşleşmeyende ayrı istek. Kimlik oruç gününe bağlı
  (`sahur.<fastingDate>`, `iftar.<fastingDate>`, konum saat dilimi); mod kimliğe girmez, fingerprint
  değişir. Testler: ilk sahurun önceki Gregoryen güne taşması, DST, saat dilimi değişimi, 29/30. gün.
  Default AÇIK (normal banner); Focus-delme opt-in. Yaklaşık kaynakta gövde "yaklaşık takvime göre".
- **R3 — Kaynaklı Ramazan imsakiyesi + paylaşım** (T2): 30 günlük tablo, tahmini satırda `≈` ve ±1 gün
  bandı, gerçek imsakiye paylaşım kartı (tebrik kartı değil); 32 gün ötesi geri sayım (yaklaşık, etiketli).
- **R4 — Cihaz doğrulaması** (kullanıcı cihazı): bildirim, Live Activity, farklı saat dilimi.
- **R5 — Widget + Watch komplikasyonu** (T2; Watch premium kilidi korunur).
- **R6 — Mağaza/büyüme**: Ramazan ASO, In-App Event'ler (tarih teyidi), ekran görüntüleri, Featuring.
  R4 sonrası. Yeni açık-varsayılan bildirim metinleri mevcut kullanıcılar için "Yenilikler"de duyurulur.

## Riskler
- Bildirim kotası (iOS 64 bekleyen; kod 60 kullanır): R1 olmadan R2 yazılmaz.
- Umm al-Qura ↔ Diyanet 1 gün sapabilir → tahmin ayrı modelde, etiketli, sınır günü bildirimi yok.
- İftar güvenlik payı (`ApproxSafetyMargin`) yalnızca yaklaşık kaynaklarda ve tek kez uygulanır.
- VISION'ın 60/74 sayımı bağımsız doğrulanmadı → R1'de testle doğrulanacak.

## Durum (18 Eki 2026)
- **R0:** `HijriEstimate` modeli yazıldı; HENÜZ hiçbir tüketicisi yok (kaynak/güven alanı, "Ramazan
  başladı mı?" düzeltmesi, yaklaşık-etiketli bildirim → sıradaki iş). Şu an Diyanet-dışı kaynakta
  Ramazan bildirimi YOK (bilinçli, güvenli taraf).
- **R2 (sahur/iftar) uygulandı** (`feat/ramadan-sahur-iftar`). VISION diff RET'i sonrası düzeltilenler:
  Akşam kapalıyken `iftar.<fastingDate>` ayrı istek; sahur+imsak ön-hatırlatması aynı dakikada tek
  bildirim; Watch'ta ek sahur kapalı, metin dönüşümü telefonla tutarlı; `sahurLeadMinutes` tek noktadan
  doğrulanır. NATASHA: bulgu kapandı.
- **Bilinen sınır (R1 tam yapılmadı):** `buildDesiredItems` bütçe aşımında hâlâ sessiz keser ve düşenler
  `deferred` sayılmaz (bu davranış Ramazan'dan ÖNCE de vardı; günlük app/BG yenilemesi pencereyi
  kaydırarak telafi eder). Tam bütçe tahsisçisi (nihai ≤60 küme + deferred sayımı) ayrı iş olarak R3
  sonrasına bırakıldı. Eksik testler: DST, saat dilimi değişimi, önceki Gregoryen güne taşan ilk sahur.
