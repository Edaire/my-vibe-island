#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
app=${1:-${TARGET_BUILD_DIR:-${BUILT_PRODUCTS_DIR:-}}/${WRAPPER_NAME:-Vibe Island.app}}
entitlements=${2:-"$repo_root/Xcode/VibeIsland/LocalSignedDev.entitlements"}
test -d "$app/Contents" || { echo "missing built app: $app" >&2; exit 1; }

"$repo_root/Scripts/sign-embedded-payload.sh" "$app"

codesign --force --sign - --options runtime --timestamp=none --entitlements "$entitlements" "$app"
codesign --verify --deep --strict --verbose=4 "$app"
codesign -d --entitlements :- "$app" 2>/dev/null | grep -q 'com.apple.security.automation.apple-events'
echo "LocalSignedDev signing: ok"
