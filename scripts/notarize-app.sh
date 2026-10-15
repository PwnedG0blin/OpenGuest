#!/bin/bash
# Run on the signing Mac. Private keys and notary credentials stay in its Keychain.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
    echo "Für Veröffentlichung auf einem Apple-Silicon-Mac ausführen."; exit 1
fi
identity="${OPENGUEST_SIGNING_IDENTITY:-}"
profile="${OPENGUEST_NOTARY_PROFILE:-}"
if [[ "$identity" != 'Developer ID Application: '* || -z "$profile" ]]; then
    echo "Developer ID Application und ein lokales notarytool-Schlüsselbundprofil erforderlich."
    echo "Siehe SIGNIERUNG.md. Keine Passwörter oder privaten Zertifikate in den Quellcode eintragen."
    exit 1
fi
cd "$project_dir"
bash scripts/build-app.sh
app="$project_dir/dist/OpenGuest.app"
/usr/bin/codesign --force --sign "$identity" --options runtime --timestamp "$app"
/usr/bin/codesign --verify --strict --verbose=2 "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Ungültige Versionsnummer."; exit 1; fi
work="$(mktemp -d "$project_dir/dist/notarize.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$work/app.zip"
/usr/bin/xcrun notarytool submit "$work/app.zip" --keychain-profile "$profile" --wait
/usr/bin/xcrun stapler staple "$app"
/usr/bin/xcrun stapler validate "$app"
/usr/sbin/spctl --assess --type execute --verbose=2 "$app"
mkdir "$work/installer"
/usr/bin/ditto "$app" "$work/installer/OpenGuest.app"
ln -s /Applications "$work/installer/Applications"
image="$project_dir/dist/OpenGuest_${version}_AppleSilicon_notarisiert.dmg"
/usr/bin/hdiutil create -volname OpenGuest -srcfolder "$work/installer" -ov -format UDZO "$image"
/usr/bin/codesign --sign "$identity" --timestamp "$image"
/usr/bin/xcrun notarytool submit "$image" --keychain-profile "$profile" --wait
/usr/bin/xcrun stapler staple "$image"
/usr/bin/xcrun stapler validate "$image"
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$image"
echo "Developer-ID-signierte und notarisierte DMG: $image"
