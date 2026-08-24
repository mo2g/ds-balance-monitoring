#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate

# clean build guarantees the new source is compiled into a fresh binary
xcodebuild -project DSBalanceMonitor.xcodeproj -scheme DSBalanceMonitor \
  -configuration Release -derivedDataPath build/DerivedData clean build

APP="build/DerivedData/Build/Products/Release/DSBalanceMonitor.app"
mkdir -p build

# Remove the previous app first: `cp -R` into an existing directory would
# nest the new app inside the old one instead of replacing it.
rm -rf build/DSBalanceMonitor.app
codesign --force --deep --sign - "$APP"
ditto "$APP" build/DSBalanceMonitor.app

# Fail loudly if any source file is newer than the produced binary,
# so the user can never silently launch a stale app again.
BIN="build/DSBalanceMonitor.app/Contents/MacOS/DSBalanceMonitor"
if NEWER_SRC="$(find App Core Models -name '*.swift' -newer "$BIN" -print -quit)"; then
  if [ -n "$NEWER_SRC" ]; then
    echo "ERROR: build produced a stale binary; $NEWER_SRC is newer than $BIN" >&2
    exit 1
  fi
fi

echo "Built: $(pwd)/build/DSBalanceMonitor.app"
