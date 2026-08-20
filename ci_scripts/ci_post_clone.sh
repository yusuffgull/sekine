#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

defaults delete com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile 2>/dev/null || true
defaults delete com.apple.dt.Xcode IDEDisableAutomaticPackageResolution 2>/dev/null || true

if ! command -v xcodegen >/dev/null 2>&1; then
    brew install xcodegen
fi

xcodegen generate

xcodebuild -resolvePackageDependencies -project Sekine.xcodeproj
