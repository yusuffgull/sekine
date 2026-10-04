# In-App Events (ASC'de DRAFT olarak girildi, 4 Eki 2026 — incelemeye gönderim kullanıcı onayıyla)

**Tarihler Diyanet'in kendi tablosundan DOĞRULANDI** (https://vakithesaplama.diyanet.gov.tr/dinigunler.php, 2026 tablosu + icerik.php?icerik=154, 2027): Regaib/Üç Aylar 1 Receb 1448 = 10 Ara 2026 Per; Miraç 26 Receb = 4 Oca 2027 Pzt; Berat 14 Şaban = 22 Oca Cum; Ramazan başı 8 Şub Pzt; Arefe 8 Mar; Bayram 9–11 Mar. ASC'de girilen aralıklar: Regaib 10–12 Ara (yayın 28 Kas), Miraç 4–6 Oca (22 Ara), Berat 22–24 Oca (8 Oca), Ramazan'a Hazırlık 18 Oca–8 Şub (4 Oca, Premiere), Ramazan Başladı 8 Şub–9 Mar (25 Oca, Major Update). Kandil gecesi o gün AKŞAMI başlar. Görseller: `scripts/generate-event-images.sh` → `store/events/`.

---
(Aşağıdaki orijinal taslak notu:)

Uygulamadaki dini gün verisi (`Sekine/Resources/HolyDays.json`) HİCRİ ay/gün tutuyor;
miladi karşılıkları burada TAHMİN edilmedi. **Her event'in tarihini Diyanet'in resmi
"Dini Günler ve Geceler" takviminden doğrula** (Umm al-Qura hesabı Diyanet'ten 1-2 gün
sapabilir). ASC kuralı: event başlangıcından en geç birkaç hafta önce girilir, review'a
girer; Türkçe (tr) metin + 1920×1080 görsel gerekir (görsel: AI arka plan, YAZISIZ; başlık
ASC alanında).

| Event | Hicri | Tür | Ne zaman gönder |
|---|---|---|---|
| Regaib Kandili | Recep'in ilk Cuma gecesi | Special Event | tarihten ~3 hafta önce |
| Miraç Kandili | 26 Recep gecesi | Special Event | ~3 hafta önce |
| Berat Kandili | 14 Şaban gecesi | Special Event | ~3 hafta önce |
| Ramazan'a Hazırlık | Şaban sonu | Premiere/Major update | Ramazan'dan ~3 hafta önce (Ramazan 2027 ≈ 8 Şubat — tarihi doğrula) |
| Ramazan Başladı | 1 Ramazan | Major update | Ramazan başlangıcından ~2 hafta önce |

## Metinler (Name ≤30, Short Description ≤50, Long Description ≤120 karakter — ASC sınırları)

**Regaib / Miraç / Berat (şablon, adı değiştir):**
- Name: `Regaib Kandili'ne Hazırlık`
- Short: `Kandil vakti ve hatırlatmalar Sekine'de`
- Long: `Kandil günü ve gecesi bildirimleri açık kalsın. Reklamsız, takipsiz, Diyanet uyumlu vakitler.`

**Ramazan'a Hazırlık:**
- Name: `Ramazan'a Hazırlık`
- Short: `Sahur ve iftar sayacı, oruç takibi`
- Long: `Ramazan'da ana ekran iftar ve sahur sayacına döner; oruç günlerini işaretleyin. Reklamsız.`

**Ramazan Başladı:**
- Name: `Ramazan Başladı`
- Short: `İftara kalan süre, tek dokunuşla paylaşım`
- Long: `Diyanet vakitleriyle iftar sayacı, oruç günü takibi ve aile grubuna vakit kartı. Reklam yok.`

Notlar: "Reklamsız/uygunsuz reklam yok" vurgusu rakip yorum analizinin #1 bulgusuna
(bkz. `docs/decisions.md` 2026-09-23) dayanır. Karakter sayılarını ASC girişinde tekrar
kontrol et. Event deep link'i gerekmez (Ana ekran açılır).
