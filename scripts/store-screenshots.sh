#!/bin/sh
# Resizes iPhone screenshots to the App Store Connect slots, alpha stripped
# (App Store Connect rejects PNGs with an alpha channel).
#   6.9" → 1320×2868 (the one slot Apple requires)
#   6.5" → 1284×2778 (optional, kept for older listings)
# Any portrait iPhone shot (~0.46 aspect) scales with no visible distortion.
#
# Usage: scripts/store-screenshots.sh <dir-of-pngs-or-jpgs> [out-dir]
set -e
IN=${1:?usage: $0 <input-dir> [out-dir]}
OUT=${2:-docs/release/screenshots}
mkdir -p "$OUT/6.9" "$OUT/6.5"

for f in "$IN"/*.png "$IN"/*.PNG "$IN"/*.jpg "$IN"/*.jpeg "$IN"/*.JPG "$IN"/*.HEIC; do
  [ -f "$f" ] || continue
  name=$(basename "${f%.*}")
  sips -s format jpeg -s formatOptions 95 -z 2868 1320 "$f" --out "$OUT/6.9/$name.jpg" >/dev/null
  sips -s format jpeg -s formatOptions 95 -z 2778 1284 "$f" --out "$OUT/6.5/$name.jpg" >/dev/null
  echo "$name"
done
