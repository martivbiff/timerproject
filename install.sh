#!/bin/bash
# Builds Flow Timer and drops it in /Applications.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
DEST="/Applications/Flow Timer.app"
rm -rf "$DEST"
cp -R "build/Flow Timer.app" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true
echo "✓ installed to $DEST"
open -a "$DEST"
