#!/bin/sh
# Simulates what Xcode Cloud does on a fresh clone: no Sekine.xcodeproj on disk
# (it's gitignored), then run the exact post-clone script, then archive.
# Run this before pushing anything that touches project.yml or ci_scripts/.
set -e

cd "$(dirname "$0")/.."

rm -rf Sekine.xcodeproj
ci_scripts/ci_post_clone.sh

# CODE_SIGNING_ALLOWED=NO: catches project-generation/package/compile errors like
# Xcode Cloud's archive step does, without local vs. managed-CI signing mismatches
# (App Groups / Time Sensitive Notifications entitlements differ locally).
xcodebuild -project Sekine.xcodeproj -scheme Sekine -destination "generic/platform=iOS" \
    CODE_SIGNING_ALLOWED=NO build

echo "OK: post-clone + build succeeded (signing not checked — Xcode Cloud handles that separately)."
