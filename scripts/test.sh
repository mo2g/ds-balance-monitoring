#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project DSBalanceMonitor.xcodeproj -scheme DSBalanceMonitor \
  -configuration Debug -destination 'platform=macOS' test
