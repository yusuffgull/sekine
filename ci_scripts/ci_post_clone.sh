#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

if ! command -v xcodegen >/dev/null 2>&1; then
    brew install xcodegen
fi

xcodegen generate

xcodebuild -resolvePackageDependencies -project Sekine.xcodeproj -scheme Sekine
