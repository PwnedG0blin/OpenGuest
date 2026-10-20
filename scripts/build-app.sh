#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Stratovo benötigt einen Apple-Silicon-Mac und ein natives Terminal (ohne Rosetta)." >&2
    exit 1
fi
if ! xcrun --find swift >/dev/null 2>&1; then
    echo "Bitte Xcode beziehungsweise die Xcode Command Line Tools installieren." >&2
    exit 1
fi
cd "$project_dir"
python3 scripts/test-embedded-display.py
python3 scripts/test-player-surfaces.py
python3 scripts/test-native-geometry.py
python3 scripts/test-native-window.py
python3 scripts/test-display-rate.py
python3 -m unittest discover -s Tests/GraphicsLabTests -q
python3 -m unittest discover -s Tests/AndroidDataTests -q
python3 scripts/test-storage-cleanup.py
xcrun swift test
xcrun swift build -c release --arch arm64
binary_dir="$(xcrun swift build -c release --arch arm64 --show-bin-path)"
app_path="$project_dir/dist/Stratovo.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/Stratovo" "$app_path/Contents/MacOS/Stratovo"
/usr/bin/ditto "$binary_dir/Stratovo_StratovoCore.bundle" "$app_path/Contents/Resources/Stratovo_StratovoCore.bundle"
cp "$project_dir/Packaging/Info.plist" "$app_path/Contents/Info.plist"
cp "$project_dir/LICENSE" "$project_dir/AUTHORS.md" "$project_dir/THIRD_PARTY_NOTICES.md" "$project_dir/SIGNIERUNG.md" "$app_path/Contents/Resources/"
cp "$project_dir/Android_Werkzeuge_einrichten.command" "$project_dir/Android_einrichten.command" "$project_dir/Android_System_verwalten.command" "$project_dir/Android_Streaming_einrichten.command" "$project_dir/Windows_Treiber_einrichten.command" "$app_path/Contents/Resources/"
cp "$project_dir/LIES_MICH_ZUERST.md" "$app_path/Contents/Resources/"
cp "$project_dir/Android_Daten_uebernehmen.py" "$app_path/Contents/Resources/"
cp "$project_dir/Packaging/install-update.sh" "$app_path/Contents/Resources/"
/usr/bin/ditto "$project_dir/Packaging/GraphicsLab" "$app_path/Contents/Resources/GraphicsLab"
mkdir -p "$app_path/Contents/Resources/scripts"
cp "$project_dir/Aufraeumen.command" "$app_path/Contents/Resources/"
cp "$project_dir/scripts/storage-cleanup.py" "$project_dir/scripts/trash-packages.swift" "$app_path/Contents/Resources/scripts/"
bash scripts/build-icon.sh
# Local development signature only. It is not Developer ID signing or notarization.
/usr/bin/codesign --force --sign - "$app_path"
/usr/bin/codesign --verify --strict "$app_path"
echo "Lokale Test-App erstellt: $app_path"
if [[ "${1:-}" == "--open" ]]; then /usr/bin/open "$app_path"; fi
