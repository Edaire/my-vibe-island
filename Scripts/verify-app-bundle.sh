#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
bundle=${1:?"usage: verify-app-bundle.sh APP_OR_PAYLOAD [MANIFEST] [--unsigned-payload]"}
manifest=${2:-"$repo_root/Xcode/VibeIsland/OriginalBundleManifest.json"}
mode=${3:-}
test -f "$manifest" || { echo "missing manifest: $manifest" >&2; exit 1; }

python3 - "$bundle" "$manifest" "$mode" <<'PY'
import hashlib
import json
import os
import plistlib
import stat
import subprocess
import sys

root, manifest_path, mode = sys.argv[1:]
with open(manifest_path, "rb") as fh:
    manifest = json.load(fh)

def fail(message):
    raise SystemExit(message)

def path_for(relative):
    return os.path.join(root, "Contents", relative) if os.path.basename(root).endswith(".app") else os.path.join(root, relative)

for relative in manifest["requiredPaths"]:
    if not os.path.lexists(path_for(relative)):
        fail("missing required path: " + relative)

for relative, expected in manifest.get("executableModes", {}).items():
    path = path_for(relative)
    actual = format(stat.S_IMODE(os.lstat(path).st_mode), "04o")
    if actual != expected:
        fail("mode mismatch for %s: %s != %s" % (relative, actual, expected))

signed_paths = set(manifest.get("signedPaths", []))
for relative, expected in manifest["sha256"].items():
    path = path_for(relative)
    with open(path, "rb") as fh:
        actual = hashlib.sha256(fh.read()).hexdigest()
    if actual != expected:
        fail("sha256 mismatch for %s: %s != %s" % (relative, actual, expected))

if os.path.basename(root).endswith(".app"):
    plist_path = os.path.join(root, "Contents", "Info.plist")
    if not os.path.isfile(plist_path):
        fail("missing Contents/Info.plist")
    with open(plist_path, "rb") as fh:
        plist = plistlib.load(fh)
    for key, expected in manifest.get("infoPlist", {}).items():
        if plist.get(key) != expected:
            fail("Info.plist %s mismatch: %r != %r" % (key, plist.get(key), expected))
    if plist.get("CFBundleExecutable") != "vibe-island":
        fail("unexpected main executable name")

for relative, expected_arches in manifest.get("architectures", {}).items():
    path = path_for(relative)
    actual = subprocess.check_output(["file", path], text=True)
    for architecture in expected_arches:
        if architecture not in actual:
            fail("architecture %s missing from %s" % (architecture, relative))

if mode == "--unsigned-payload":
    for directory in ("Frameworks", "Helpers", "Resources"):
        for current, dirs, files in os.walk(path_for(directory)):
            if "_CodeSignature" in dirs:
                fail("forbidden _CodeSignature: " + os.path.join(current, "_CodeSignature"))

if mode != "--unsigned-payload" and os.path.basename(root).endswith(".app"):
    for relative in signed_paths:
        subprocess.check_call(["codesign", "--verify", "--strict", "--verbose=2", path_for(relative)])
    subprocess.check_call(["codesign", "--verify", "--deep", "--strict", "--verbose=4", root])
print("bundle verification: ok")
PY
