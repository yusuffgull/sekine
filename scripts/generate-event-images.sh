#!/bin/sh
# In-App Event kapak görselleri (1920x1080): marka yeşili + hilal/yıldız, başlık kodla yazılır
# (Türkçe karakterler bozulmasın). Çıktı: store/events/<slug>.png
set -e
cd "$(dirname "$0")/.."
work=$(mktemp -d)
render() { # slug title subtitle
  cat > "$work/$1.html" <<HTML
<html><head><meta charset="utf-8"></head><body style="margin:0;width:1920px;height:1080px;background:radial-gradient(circle at 70% 30%,#2E8A73 0%,#1F6E5C 45%,#124236 100%);font-family:-apple-system,'Helvetica Neue',sans-serif;color:#F7F1E3;position:relative;overflow:hidden">
<svg style="position:absolute;right:140px;top:110px" width="520" height="520" viewBox="0 0 100 100"><defs><mask id="m"><rect width="100" height="100" fill="white"/><circle cx="64" cy="42" r="34" fill="black"/></mask></defs><circle cx="46" cy="52" r="40" fill="#E6C77A" mask="url(#m)"/><g fill="#E6C77A"><path d="M78 24l2.2 5.8 5.8 2.2-5.8 2.2-2.2 5.8-2.2-5.8-5.8-2.2 5.8-2.2z"/><path d="M90 60l1.4 3.6 3.6 1.4-3.6 1.4-1.4 3.6-1.4-3.6-3.6-1.4 3.6-1.4z"/></g></svg>
<div style="position:absolute;left:150px;bottom:230px;max-width:1100px">
<div style="font-size:64px;letter-spacing:6px;opacity:.85;margin-bottom:24px">SEKİNE</div>
<div style="font-size:120px;font-weight:700;line-height:1.08">$2</div>
<div style="font-size:52px;margin-top:34px;opacity:.9">$3</div></div></body></html>
HTML
  swift scripts/html-to-png.swift "$work/$1.html" "$work/$1.png" 1920 1080
  # WKWebView 2x çözünürlükte çizer → tam 1920x1080 JPEG'e indir (ASC event görsel boyutu)
  sips -z 1080 1920 -s format jpeg -s formatOptions 90 "$work/$1.png" --out "store/events/$1.jpg" >/dev/null
}
render_portrait() { # slug title subtitle -> 1080x1920 (Event Details Page)
  cat > "$work/$1-p.html" <<HTML
<html><head><meta charset="utf-8"></head><body style="margin:0;width:1080px;height:1920px;background:radial-gradient(circle at 60% 25%,#2E8A73 0%,#1F6E5C 50%,#124236 100%);font-family:-apple-system,'Helvetica Neue',sans-serif;color:#F7F1E3;position:relative;overflow:hidden">
<svg style="position:absolute;left:290px;top:230px" width="500" height="500" viewBox="0 0 100 100"><defs><mask id="m"><rect width="100" height="100" fill="white"/><circle cx="64" cy="42" r="34" fill="black"/></mask></defs><circle cx="46" cy="52" r="40" fill="#E6C77A" mask="url(#m)"/><g fill="#E6C77A"><path d="M78 24l2.2 5.8 5.8 2.2-5.8 2.2-2.2 5.8-2.2-5.8-5.8-2.2 5.8-2.2z"/><path d="M90 60l1.4 3.6 3.6 1.4-3.6 1.4-1.4 3.6-1.4-3.6-3.6-1.4 3.6-1.4z"/></g></svg>
<div style="position:absolute;left:90px;right:90px;top:1000px;text-align:center">
<div style="font-size:48px;letter-spacing:6px;opacity:.85;margin-bottom:24px">SEKİNE</div>
<div style="font-size:104px;font-weight:700;line-height:1.1">$2</div>
<div style="font-size:46px;margin-top:34px;opacity:.9">$3</div></div></body></html>
HTML
  swift scripts/html-to-png.swift "$work/$1-p.html" "$work/$1-p.png" 1080 1920
  sips -z 1920 1080 -s format jpeg -s formatOptions 90 "$work/$1-p.png" --out "store/events/$1-portrait.jpg" >/dev/null
}
render regaib "Regaib Kandili" "Reklamsız. Takipsiz. Sadece huzur."
render_portrait regaib "Regaib Kandili" "Reklamsız. Takipsiz. Sadece huzur."
render miraj "Miraç Kandili" "Kandil vakti ve hatırlatmalar Sekine'de"
render_portrait miraj "Miraç Kandili" "Kandil vakti ve hatırlatmalar Sekine'de"
render berat "Berat Kandili" "Kandil vakti ve hatırlatmalar Sekine'de"
render_portrait berat "Berat Kandili" "Kandil vakti ve hatırlatmalar Sekine'de"
render ramazan-hazirlik "Ramazan'a Hazırlık" "Sahur ve iftar sayacı, oruç takibi"
render_portrait ramazan-hazirlik "Ramazan'a Hazırlık" "Sahur ve iftar sayacı, oruç takibi"
render ramazan-basladi "Ramazan Başladı" "İftara kalan süre, tek dokunuşla paylaşım"
render_portrait ramazan-basladi "Ramazan Başladı" "İftara kalan süre, tek dokunuşla paylaşım"
