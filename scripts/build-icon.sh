#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
icon_work="$(mktemp -d "${TMPDIR:-/tmp}/stratovo-icon.XXXXXX")"
trap 'rm -rf "$icon_work"' EXIT
mkdir "$icon_work/Stratovo.iconset"
for size in 16 32 128 256 512; do
    /usr/bin/sips -s format png -z "$size" "$size" "$project_dir/Packaging/AppIcon.jpg" --out "$icon_work/Stratovo.iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    /usr/bin/sips -s format png -z "$retina" "$retina" "$project_dir/Packaging/AppIcon.jpg" --out "$icon_work/Stratovo.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p "$project_dir/dist/Stratovo.app/Contents/Resources"
/usr/bin/iconutil -c icns "$icon_work/Stratovo.iconset" -o "$project_dir/dist/Stratovo.app/Contents/Resources/Stratovo.icns"
test -s "$project_dir/dist/Stratovo.app/Contents/Resources/Stratovo.icns"
