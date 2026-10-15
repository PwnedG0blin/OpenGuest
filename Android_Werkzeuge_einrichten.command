#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
    echo "Apple-Silicon-Mac benötigt."; exit 1
fi
config="$HOME/Library/Application Support/OpenGuest/storage.json"
root="$(/usr/bin/plutil -extract root raw -o - "$config")"
id="$(/usr/bin/plutil -extract id raw -o - "$config")"
if [[ ! -f "$root/.openguest-storage-id" ]] || [[ "$(cat "$root/.openguest-storage-id")" != "$id" ]]; then
    echo "Gewählter Datenträger fehlt. Kein interner Ersatzdownload."; exit 1
fi
mkdir -p "$root/Downloads" "$root/Runtime/Java" "$root/Android/sdk/cmdline-tools"
work="$(mktemp -d "$root/Downloads/android-tools.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
if [[ ! -x "$root/Android/sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
    if [[ -e "$root/Android/sdk/cmdline-tools/latest" ]]; then
        echo "Unvollständiger Ordner cmdline-tools/latest vorhanden. Er wird nicht überschrieben."; exit 1
    fi
    echo "Lade offizielle Android SDK Command-line Tools für Mac ARM64."
    /usr/bin/curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --max-time 1800 \
        'https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip' -o "$work/tools.zip"
    expected='835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e'
    actual="$(/usr/bin/shasum -a 256 "$work/tools.zip" | /usr/bin/awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then echo "SDK-Prüfsumme stimmt nicht. Abbruch."; exit 1; fi
    /usr/bin/unzip -q "$work/tools.zip" -d "$work/unpacked"
    if [[ ! -f "$work/unpacked/cmdline-tools/bin/sdkmanager" ]]; then echo "Ungültiges SDK-Paket."; exit 1; fi
    mv "$work/unpacked/cmdline-tools" "$root/Android/sdk/cmdline-tools/latest"
fi
if [[ -x '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java' ]]; then
    echo "Java aus Android Studio wird wiederverwendet."; exit 0
fi
shopt -s nullglob
for java in "$root"/Runtime/Java/*/Contents/Home/bin/java; do
    if [[ -x "$java" ]]; then echo "Java auf dem gewählten Datenträger ist vorhanden."; exit 0; fi
done
if ! command -v python3 >/dev/null; then echo "Python 3 für die Downloadprüfung fehlt (Xcode Command Line Tools)."; exit 1; fi
echo "Lade Eclipse Temurin Java 21 ARM64 direkt auf den gewählten Datenträger."
/usr/bin/curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --max-time 120 \
    'https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=aarch64&image_type=jre&os=mac&vendor=eclipse' -o "$work/java.json"
python3 - "$work" <<'PY'
import json, pathlib, re, sys, urllib.parse
root = pathlib.Path(sys.argv[1])
assets = json.loads((root / 'java.json').read_text())
asset = next((a for a in assets if a.get('binary', {}).get('architecture') == 'aarch64'
              and a['binary'].get('os') == 'mac' and a['binary'].get('image_type') == 'jre'), None)
if not asset: raise SystemExit('Kein passendes Java-21-Paket gefunden.')
package = asset['binary']['package']
url = package['link']
parsed = urllib.parse.urlparse(url)
if parsed.scheme != 'https' or parsed.netloc != 'github.com' or not parsed.path.startswith('/adoptium/temurin21-binaries/releases/download/'):
    raise SystemExit('Unerwartete Java-Downloadquelle.')
if not re.fullmatch('[0-9a-fA-F]{64}', package.get('checksum', '')):
    raise SystemExit('Java-Prüfsumme fehlt.')
(root / 'java-url.txt').write_text(url)
(root / 'java-sha.txt').write_text(package['checksum'].lower())
PY
/usr/bin/curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 --max-time 1800 \
    "$(cat "$work/java-url.txt")" -o "$work/java.tar.gz"
actual="$(/usr/bin/shasum -a 256 "$work/java.tar.gz" | /usr/bin/awk '{print $1}')"
if [[ "$actual" != "$(cat "$work/java-sha.txt")" ]]; then echo "Java-Prüfsumme stimmt nicht."; exit 1; fi
mkdir "$work/java"
/usr/bin/tar -xzf "$work/java.tar.gz" -C "$work/java"
found=false
for directory in "$work"/java/*; do
    if [[ -x "$directory/Contents/Home/bin/java" ]]; then
        target="$root/Runtime/Java/$(basename "$directory")"
        if [[ -e "$target" ]]; then echo "Java-Ziel existiert bereits und bleibt unverändert."; exit 1; fi
        mv "$directory" "$target"
        found=true
    fi
done
if [[ "$found" != true ]]; then echo "Ungültiges Java-Paket."; exit 1; fi
echo "Android-Werkzeuge auf dem gewählten Datenträger eingerichtet."
