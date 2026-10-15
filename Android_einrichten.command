#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "Dieses Skript benötigt einen Apple-Silicon-Mac." >&2; exit 1
fi
sdk_path="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
sdk_manager="$sdk_path/cmdline-tools/latest/bin/sdkmanager"
avd_manager="$sdk_path/cmdline-tools/latest/bin/avdmanager"
if [[ ! -x "$sdk_manager" || ! -x "$avd_manager" ]]; then
    echo "Bitte Android Studio für Apple Silicon installieren und im SDK Manager die Android SDK Command-line Tools (latest) auswählen." >&2
    echo "Danach dieses Skript erneut starten. Es werden keine bestehenden AVDs gelöscht." >&2
    exit 1
fi
if [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
export ANDROID_HOME="$sdk_path"
export ANDROID_SDK_ROOT="$sdk_path"
echo "Die folgenden Android-Lizenzen bitte selbst lesen und bestätigen."
"$sdk_manager" --sdk_root="$sdk_path" --licenses
image_id='system-images;android-35;google_apis_playstore;arm64-v8a'
"$sdk_manager" --sdk_root="$sdk_path" "platform-tools" "emulator" "$image_id"
avd_names="$("$avd_manager" list avd -c)"
already_exists=false
while IFS= read -r name; do
    if [[ "$name" == "OpenGuest_GooglePlay" ]]; then already_exists=true; fi
done <<< "$avd_names"
if [[ "$already_exists" == true ]]; then
    echo "OpenGuest_GooglePlay existiert bereits und bleibt unverändert."
else
    printf 'no\n' | "$avd_manager" create avd --name OpenGuest_GooglePlay --package "$image_id" --device pixel_7
fi
echo "Google-Play-Gerät vorbereitet. Beim ersten Android-Start selbst bei Google anmelden."
echo "Nächster Schritt: Android_Streaming_einrichten.command und danach Start.command."
