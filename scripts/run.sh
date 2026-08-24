#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Close any running instance first; `open` alone would just focus the old
# process and never load the newly built binary.
pkill -f 'DSBalanceMonitor.app/Contents/MacOS/DSBalanceMonitor' 2>/dev/null || true
sleep 1

./scripts/build.sh
open -n build/DSBalanceMonitor.app
echo "Launched: $(pwd)/build/DSBalanceMonitor.app"
