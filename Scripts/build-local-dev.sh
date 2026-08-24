#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
derived_data=${VIBE_ISLAND_DERIVED_DATA:-"$repo_root/.build/xcode-derived"}
app="$derived_data/Build/Products/Debug/Vibe Island.app"
run=false

if test $# -gt 1 || { test $# -eq 1 && test "$1" != "--run"; }; then
  echo "usage: $0 [--run]" >&2
  exit 2
fi
test "${1:-}" = "--run" && run=true

cd "$repo_root"
xcodebuild -quiet \
  -project VibeIsland.xcodeproj \
  -scheme VibeIsland-LocalSignedDev \
  -configuration Debug \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

Scripts/sign-local-dev.sh "$app"
Scripts/verify-app-bundle.sh "$app"

if $run; then
  open "$app"
fi

echo "$app"
