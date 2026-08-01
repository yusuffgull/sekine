# Handoff

## CURRENT TASK
v1 iOS uygulaması kod-tamam ve derleniyor. Sırada GitHub'a push ve App Store gönderim
hazırlığı var. Kod yazımı gerektiren teknik iş kalmadı; kalanlar hesap/store işlemleri
ve submit öncesi Diyanet doğruluk doğrulaması.

## DONE
- Native SwiftUI (iOS 17+) tam uygulama: Onboarding, Home (canlı geri sayım), Aylık
  imsakiye, Kıble, Ayarlar, WidgetKit widget.
- Kaynak-bağımsız vakit katmanı: AladhanProvider (method=13) + LocalCalculationProvider
  (adhan-swift fallback) + cache (app group / Documents).
- RollingScheduler: iOS 64-bildirim penceresini kayan şekilde tazeler; app açılışı +
  BGAppRefresh + willPresent tetikleyicileri.
- Reklamsız, backend'siz, tracking'siz. İkon + orijinal chime.caf sesi.
- `xcodebuild build` başarılı; 7/7 unit test geçti; simülatörde Onboarding + Home gerçek
  Aladhan verisiyle görsel doğrulandı (İstanbul vakitleri birebir).

## NEXT
1. GitHub'a push (private repo `yusuffgull/sekine`) — kullanıcı onayı bekliyor.
2. **Submit öncesi zorunlu:** Aladhan method=13 vaktini İstanbul/Ankara/İzmir için
   Diyanet resmi sitesiyle karşılaştır (özellikle İmsak/Fajr). Sapma varsa Diyanet
   resmi API sağlayıcısını ekle (mimari hazır, `PrayerTimeProvider`).
3. Xcode'da DEVELOPMENT_TEAM ayarla (project.yml boş), app group provisioning'i etkinleştir.
4. App Store adı "Sekine" müsaitlik kontrolü; gizlilik "nutrition label" (veri toplanmıyor);
   açıklama/anahtar kelime/ekran görüntüleri; TestFlight → submit.

## BLOCKERS
Yok. (Store işlemleri kullanıcının Apple hesabıyla yapılacak; DEVELOPMENT_TEAM ve
signing kullanıcı tarafında ayarlanmalı.)

## BEST AGENT NOW
Claude — release/submission hazırlığı ve Diyanet doğruluk doğrulaması karar gerektirir.
