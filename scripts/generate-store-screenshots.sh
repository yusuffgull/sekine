#!/bin/sh
# Regenerates polished App Store marketing screenshots from the raw device
# screenshots in store/screenshots/ (6.9", 1320x2868), using an HTML/CSS design
# rendered via WKWebView (scripts/html-to-png.swift) — no external services, no
# Chrome required. Outputs:
#   store/screenshots-marketing/     6.9" (1320x2868) — primary ASC upload
#   store/screenshots-marketing-6.5/ 6.5" (1284x2778) — resized from the above
#     (uniform ~97% scale, same source render, no separate capture needed)
#   store/screenshots-watch/         Watch (422x514) raw captures, uploaded as-is
#     — the canvas already equals the physical screen size, so there is no
#     spare margin for a framed/captioned marketing treatment like the iPhone set.
set -e

cd "$(dirname "$0")/.."

work=fastlane/html-screens
mkdir -p "$work/rendered" store/screenshots-marketing store/screenshots-marketing-6.5
cp store/screenshots/*.png "$work/"

render() {
  name="$1"; headline="$2"
  sed -e "s|__HEADLINE__|${headline}|" -e "s|__IMAGE__|${name}.png|" \
    "$work/template.html" > "$work/${name}.html"
  swift scripts/html-to-png.swift "$work/${name}.html" "$work/rendered/${name}.png" 1320 2868
  # WKWebView snapshots at the display's backing scale (2x on this machine);
  # normalize down to the exact required App Store pixel sizes.
  sips -z 2868 1320 "$work/rendered/${name}.png" --out "store/screenshots-marketing/${name}.png" >/dev/null
  sips -z 2778 1284 "$work/rendered/${name}.png" --out "store/screenshots-marketing-6.5/${name}.png" >/dev/null
}

render "1-home"       "Reklamsız. Takipsiz. Sadece namaz vakti."
render "2-onboarding" "Diyanet vakitleri, çevrimdışı çalışır"
render "3-qibla"      "Kıble yönünü kolayca bulun"
render "4-monthly"    "Aylık imsakiye, tek bakışta"
render "5-settings"   "Bildirimler düzenli yenilenir, susmaz"
render "6-ramadan"    "Ramazan'da iftar ve sahur sayacı"
render "7-kaza"       "Kaza namazlarınızı takip edin"

echo "OK: marketing screenshots written to store/screenshots-marketing/ and store/screenshots-marketing-6.5/"
