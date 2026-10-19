#!/bin/bash
set -euo pipefail
config="$HOME/Library/Application Support/OpenGuest/storage.json"
if [[ ! -f "$config" ]]; then echo "Bitte zuerst in Stratovo einen Datenordner wählen."; exit 1; fi
root="$(/usr/bin/plutil -extract root raw -o - "$config")"
id="$(/usr/bin/plutil -extract id raw -o - "$config")"
if [[ ! -f "$root/.openguest-storage-id" ]] || [[ "$(cat "$root/.openguest-storage-id")" != "$id" ]]; then
    echo "SSD / gewählter Datenordner fehlt. Kein interner Ersatzdownload."; exit 1
fi
mkdir -p "$root/Installationsmedien"
if [[ -f "$root/Installationsmedien/utm-guest-tools.iso" ]]; then
    magic="$(dd if="$root/Installationsmedien/utm-guest-tools.iso" bs=1 skip=32769 count=5 2>/dev/null)"
    if [[ "$magic" == CD001 || "$magic" == BEA01 || "$magic" == NSR02 || "$magic" == NSR03 ]]; then
        echo "Vorhandene Treiber-ISO wird wiederverwendet. Kein erneuter Download."; exit 0
    fi
    echo "Vorhandene Treiber-ISO ist ungültig. Sie wird nicht überschrieben."; exit 1
fi
work="$(mktemp -d "$root/Installationsmedien/download.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
printf '%s\n' 'Lade offizielle UTM Windows Guest Tools (einschließlich ARM64-Treiber).'
/usr/bin/curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 \
    'https://getutm.app/downloads/utm-guest-tools-latest.iso' -o "$work/utm-guest-tools.iso"
magic="$(dd if="$work/utm-guest-tools.iso" bs=1 skip=32769 count=5 2>/dev/null)"
if [[ "$magic" != CD001 && "$magic" != BEA01 && "$magic" != NSR02 && "$magic" != NSR03 ]]; then
    echo "Download ist kein erkanntes ISO-Abbild. Nichts installiert."; exit 1
fi
if [[ -e "$root/Installationsmedien/utm-guest-tools.iso" ]]; then
    echo "Eine Treiber-ISO ist bereits vorhanden und bleibt unverändert."; exit 0
fi
mv "$work/utm-guest-tools.iso" "$root/Installationsmedien/utm-guest-tools.iso"
/usr/bin/shasum -a 256 "$root/Installationsmedien/utm-guest-tools.iso"
echo "Fertig. In Stratovo bei ARM64-Treiber-ISO diese Datei wählen:"
echo "$root/Installationsmedien/utm-guest-tools.iso"
echo "Nur als Treibermedium verwenden. Nicht als Windows-Installations-ISO auswählen."
