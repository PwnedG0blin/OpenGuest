#!/bin/bash
set -euo pipefail
system="${1:-16}"
mode="${2:-install}"
channel="${3:-0}"
preferred="${4:-}"
case "$system" in
  16) platform="android-36" ;;
  17) platform="android-37.0" ;;
  *) echo "Nur Android 16 oder 17 unterstützt."; exit 1 ;;
esac
case "$mode" in install|check|update) ;; *) exit 1 ;; esac
case "$channel" in 0|1|2|3) ;; *) exit 1 ;; esac
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || exit 1
config="$HOME/Library/Application Support/OpenGuest/storage.json"
root="$(/usr/bin/plutil -extract root raw -o - "$config")"
id="$(/usr/bin/plutil -extract id raw -o - "$config")"
[[ -f "$root/.openguest-storage-id" && "$(cat "$root/.openguest-storage-id")" == "$id" ]] || {
  echo "Gewählter Datenträger fehlt. Kein interner Ersatzdownload."; exit 1
}
# All guests must be stopped, also a separately launched Android Studio emulator.
if /usr/bin/pgrep -f '/emulator/qemu/|sdk/emulator/emulator' >/dev/null; then
  echo "Bitte alle Android-Emulatoren vor Installation oder Update beenden."; exit 1
fi
sdk="$root/Android/sdk"
export ANDROID_HOME="$sdk" ANDROID_SDK_ROOT="$sdk"
export ANDROID_AVD_HOME="$root/Android/avd"
export ANDROID_USER_HOME="$root/Android/user"
for directory in "$sdk" "$ANDROID_AVD_HOME" "$ANDROID_USER_HOME" "$root/Downloads/Temporary"; do
  mkdir -p "$directory"
  if [[ "$(cd "$directory" && pwd -P)" != "$directory" ]]; then
    echo "Arbeitsordner enthält eine Verknüpfung. Abbruch: $directory"; exit 1
  fi
done
export TMPDIR="$root/Downloads/Temporary/"
export JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=\"$TMPDIR\""
if [[ -x '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java' ]]; then
  export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
else
  shopt -s nullglob
  for java in "$root"/Runtime/Java/*/Contents/Home/bin/java; do
    if [[ -x "$java" ]]; then export JAVA_HOME="${java%/bin/java}"; break; fi
  done
fi
manager="$sdk/cmdline-tools/latest/bin/sdkmanager"
avdmanager="$sdk/cmdline-tools/latest/bin/avdmanager"
[[ -x "$manager" && -x "$avdmanager" ]] || { echo "Android-Werkzeuge fehlen."; exit 1; }
package="system-images;$platform;google_apis_playstore;arm64-v8a"
if [[ "$mode" == check ]]; then
  echo "Updateprüfung für Android $system · SDK-Kanal $channel. Kein Download, kein Gaststart."
  "$manager" --sdk_root="$sdk" --list --newer --channel="$channel"
  exit 0
fi
if [[ "$mode" == update ]]; then
  [[ -f "$sdk/system-images/$platform/google_apis_playstore/arm64-v8a/package.xml" ]] || {
    echo "Dieses Android-System ist noch nicht installiert."; exit 1
  }
  echo "Aktualisiere nur $package. Profile und Nutzerdaten werden nicht zurückgesetzt."
  "$manager" --sdk_root="$sdk" --channel="$channel" "$package"
  exit 0
fi
packages=("$package")
[[ -x "$sdk/platform-tools/adb" ]] || packages+=("platform-tools")
[[ -x "$sdk/emulator/emulator" ]] || packages+=("emulator")
"$manager" --sdk_root="$sdk" --channel="$channel" "${packages[@]}"
# Reuse an existing matching profile. No existing config or userdata is overwritten.
shopt -s nullglob
chosen=""
for directory in "$ANDROID_AVD_HOME"/*.avd; do
  [[ ! -L "$directory" && -f "$directory/config.ini" ]] || continue
  image="$(awk -F= '$1=="image.sysdir.1" {sub(/^[^=]*=/, ""); gsub(/\r/, ""); print; exit}' "$directory/config.ini")"
  if [[ "$image" == *"/$platform/google_apis_playstore/arm64-v8a/" || "$image" == "system-images/$platform/google_apis_playstore/arm64-v8a" ]]; then
    candidate="$(basename "$directory" .avd)"
    if [[ -z "$chosen" || "$candidate" == "$preferred" ]]; then chosen="$candidate"; fi
  fi
done
if [[ -n "$chosen" ]]; then
  echo "Vorhandenes Android $system bleibt unverändert: $chosen"
  exit 0
fi
name="Pixelkoje_Android${system}_64GB"
destination="$ANDROID_AVD_HOME/$name.avd"
[[ ! -e "$destination" && ! -L "$destination" && ! -e "$ANDROID_AVD_HOME/$name.ini" && ! -L "$ANDROID_AVD_HOME/$name.ini" ]] || {
  echo "Profilname bereits belegt; nichts überschrieben."; exit 1
}
"$avdmanager" create avd -n "$name" -k "$package" -p "$destination" --device pixel_7 <<<'no'
profile="$destination/config.ini"
awk '!/^(disk.dataPartition.size|hw.lcd.width|hw.lcd.height|hw.lcd.density|hw.keyboard)=/' "$profile" > "$profile.new"
cat >> "$profile.new" <<'VALUES'
disk.dataPartition.size=64G
hw.lcd.width=1440
hw.lcd.height=3120
hw.lcd.density=500
hw.keyboard=yes
VALUES
mv "$profile.new" "$profile"
echo "Android $system mit Google Play und 64 GiB vorbereitet. Beim ersten Start bei Google anmelden."
