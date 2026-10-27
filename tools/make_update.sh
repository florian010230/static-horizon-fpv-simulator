#!/bin/bash
# Builds the signed in-game update for a release (UpdatePack):
#   builds/update/StaticHorizonFPV-<v>-<os>.pck   (one per platform)
#   builds/update/update-manifest.json + .sig
# Upload all of them to the GitHub release next to the zips.
#
# Usage: tools/make_update.sh <version> <previous release version>
# The private key never lives in the repo: SH_UPDATE_KEY (default
# ~/.static_horizon_keys/update_signing.pem). The public half goes into
# scripts/update_key.gd once, when the key is made.
#
# min_base: a pack can't bring new class_name scripts, autoloads or
# project settings (the engine reads them before a pack loads). If any of
# those changed since the previous release's tag, min_base = this version
# (no in-game update: everyone gets the release page); otherwise
# min_base = the previous version.
set -euo pipefail
cd "$(dirname "$0")/.."
VER="${1:?version}"
PREV="${2:?previous release version}"
KEY="${SH_UPDATE_KEY:-$HOME/.static_horizon_keys/update_signing.pem}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
REPO="$(pwd -P)"

[ -f "$KEY" ] || { echo "No signing key at $KEY"; exit 1; }
case "$(cd "$(dirname "$KEY")" && pwd -P)/" in
	"$REPO"/*) echo "The signing key must not be inside the repo"; exit 1;;
esac
grep -q "config/version=\"$VER\"" project.godot || { echo "project.godot is not at version $VER"; exit 1; }

MIN_BASE="$PREV"
if ! git rev-parse -q --verify "v$PREV" >/dev/null; then
	echo "No tag v$PREV - min_base = $VER (no in-game update)"; MIN_BASE="$VER"
# (config/version changes with every release; UpdatePack sets it itself
# after loading a pack - only other project.godot changes count.)
elif git diff -U0 "v$PREV" HEAD -- project.godot | grep '^[-+]' | grep -v '^\(---\|+++\)' | grep -qv 'config/version=' \
	|| git diff "v$PREV" HEAD -- '*.gd' | grep -q '^+class_name'; then
	echo "project.godot or class_name scripts changed since v$PREV - min_base = $VER (no in-game update)"
	MIN_BASE="$VER"
fi

OUT=builds/update
mkdir -p "$OUT"
ENGINE="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')"
case "$ENGINE" in *.*.*) ;; *) ENGINE="$ENGINE.0";; esac
PACKS=""
for pair in "windows:Windows Desktop" "macos:macOS" "linux:Linux"; do
	OS="${pair%%:*}"
	PRESET="${pair#*:}"
	PCK="$OUT/StaticHorizonFPV-$VER-$OS.pck"
	"$GODOT" --headless --path . --export-pack "$PRESET" "$PCK" >/dev/null 2>&1
	SIZE=$(stat -f%z "$PCK" 2>/dev/null || stat -c%s "$PCK")
	SHA=$(shasum -a 256 "$PCK" | cut -d' ' -f1)
	PACKS="$PACKS${PACKS:+, }\"$OS\": {\"file\": \"$(basename "$PCK")\", \"size\": $SIZE, \"sha256\": \"$SHA\"}"
	echo "$OS: $PCK ($SIZE bytes)"
done
MANIFEST="$OUT/update-manifest.json"
printf '{"version": "%s", "engine": "%s", "min_base": "%s", "packs": {%s}}\n' "$VER" "$ENGINE" "$MIN_BASE" "$PACKS" > "$MANIFEST"
openssl dgst -sha256 -sign "$KEY" -out "$MANIFEST.sig" "$MANIFEST"
openssl dgst -sha256 -verify <(openssl rsa -in "$KEY" -pubout 2>/dev/null) -signature "$MANIFEST.sig" "$MANIFEST"
cat "$MANIFEST"
