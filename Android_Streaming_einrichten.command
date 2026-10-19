#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != "Darwin" ]]; then echo "Bitte auf deinem Mac ausführen." >&2; exit 1; fi
if ! command -v python3 >/dev/null; then
    echo "Python 3 wird für die Download-Prüfung benötigt (z. B. aus Xcode Command Line Tools)." >&2; exit 1
fi
storage_config="$HOME/Library/Application Support/OpenGuest/storage.json"
if [[ ! -f "$storage_config" ]]; then echo "Bitte zuerst in Stratovo einen Datenordner wählen."; exit 1; fi
storage_root="$(/usr/bin/plutil -extract root raw -o - "$storage_config")"
storage_id="$(/usr/bin/plutil -extract id raw -o - "$storage_config")"
if [[ ! -f "$storage_root/.openguest-storage-id" ]] || [[ "$(cat "$storage_root/.openguest-storage-id")" != "$storage_id" ]]; then
    echo "Gewählter Datenordner fehlt. Bitte SSD anschließen. Kein interner Ersatzdownload."; exit 1
fi
runtime_dir="$storage_root/Runtime/scrcpy-4.0"
mkdir -p "$runtime_dir"
chmod 700 "$runtime_dir"
work_dir="$(mktemp -d "$runtime_dir/download.XXXXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT
echo "Lade scrcpy 4.0 ausschließlich aus dem offiziellen Genymobile-Release."
/usr/bin/curl --fail --location --proto '=https' --tlsv1.2 --max-time 60 \
    'https://api.github.com/repos/Genymobile/scrcpy/releases/tags/v4.0' -o "$work_dir/release.json"
python3 - "$work_dir" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
release = json.loads((root / 'release.json').read_text())
if release.get('tag_name') != 'v4.0':
    raise SystemExit('Falscher Release-Tag. Download abgebrochen.')
asset = next((a for a in release.get('assets', []) if a.get('name') == 'scrcpy-server-v4.0'), None)
if not asset:
    raise SystemExit('Offizielle Server-Datei nicht gefunden. Es wird kein Ersatz ausgeführt.')
expected_url = 'https://github.com/Genymobile/scrcpy/releases/download/v4.0/scrcpy-server-v4.0'
if asset.get('browser_download_url') != expected_url:
    raise SystemExit('Unerwartete Download-Adresse. Abbruch.')
digest = asset.get('digest', '')
if not re.fullmatch(r'sha256:[a-fA-F0-9]{64}', digest):
    raise SystemExit('Der Release liefert keinen SHA-256-Prüfwert. Bitte zuerst die offizielle Veröffentlichung prüfen; automatischer Download abgebrochen.')
(root / 'manifest.json').write_text(json.dumps({'version': '4.0', 'sha256': digest[7:].lower(), 'source': expected_url}))
PY
/usr/bin/curl --fail --location --proto '=https' --tlsv1.2 --max-time 120 \
    'https://github.com/Genymobile/scrcpy/releases/download/v4.0/scrcpy-server-v4.0' -o "$work_dir/scrcpy-server-v4.0"
python3 - "$work_dir" "$runtime_dir" <<'PY'
import hashlib, json, os, pathlib, sys, zipfile
temporary, destination = map(pathlib.Path, sys.argv[1:])
jar = temporary / 'scrcpy-server-v4.0'
manifest = json.loads((temporary / 'manifest.json').read_text())
if hashlib.sha256(jar.read_bytes()).hexdigest() != manifest['sha256']:
    raise SystemExit('Prüfsumme stimmt nicht. Installation abgebrochen.')
with zipfile.ZipFile(jar) as archive:
    if 'classes.dex' not in archive.namelist() or archive.testzip() is not None:
        raise SystemExit('Ungültiges Android-Serverpaket. Installation abgebrochen.')
os.chmod(jar, 0o600)
os.chmod(temporary / 'manifest.json', 0o600)
os.replace(jar, destination / jar.name)
os.replace(temporary / 'manifest.json', destination / 'manifest.json')
print('Streaming-Modul geprüft und eingerichtet. Stratovo kann jetzt Android direkt im Player anzeigen.')
PY
