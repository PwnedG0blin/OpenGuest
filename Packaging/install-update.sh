#!/bin/bash
set -euo pipefail
app_pid="$1"
target="$2"
source_app="$3"
[[ "$app_pid" =~ ^[0-9]+$ && "$target" == /*/Stratovo.app && "$source_app" == /*/Stratovo.app ]]
[[ -d "$target" && ! -L "$target" && -d "$source_app" && ! -L "$source_app" ]]
parent="$(dirname -- "$target")"
[[ -w "$parent" ]]
for ((attempt=0; attempt<120; attempt++)); do
    if ! kill -0 "$app_pid" 2>/dev/null; then break; fi
    sleep 1
done
if kill -0 "$app_pid" 2>/dev/null; then echo "App wurde nicht beendet; keine Änderung."; exit 1; fi
stage="$(mktemp -d "$parent/.Stratovo-update.XXXXXX")"
backup="$stage/Previous-Stratovo.app"
restore() {
    if [[ -d "$backup" && ! -e "$target" ]]; then /bin/mv "$backup" "$target"; fi
}
trap restore EXIT
/usr/bin/ditto "$source_app" "$stage/Stratovo.app"
/usr/bin/codesign --verify --deep --strict "$stage/Stratovo.app"
/bin/mv "$target" "$backup"
/bin/mv "$stage/Stratovo.app" "$target"
if ! /usr/bin/open "$target"; then
    /bin/mv "$target" "$stage/Failed-Stratovo.app"
    restore
    /usr/bin/open "$target"
    exit 1
fi
echo "Update installiert. Vorherige App für Rückkehr: $backup"
