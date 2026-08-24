#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"

xcodegen generate

# Universal binary (Apple Silicon + Intel), ad-hoc signed for local/GitHub release.
xcodebuild -project DSBalanceMonitor.xcodeproj -scheme DSBalanceMonitor \
  -configuration Release -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build

APP="build/DerivedData/Build/Products/Release/DSBalanceMonitor.app"
codesign --force --deep --sign - "$APP"

rm -rf build/DSBalanceMonitor.app
ditto "$APP" build/DSBalanceMonitor.app

mkdir -p dist
ZIP="dist/DSBalanceMonitor-${VERSION}-macOS.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/DSBalanceMonitor.app "$ZIP"

echo "Release bundle: $(pwd)/$ZIP"
