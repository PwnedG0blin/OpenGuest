# Stratovo · 1.0 Beta 1

Public Apple Silicon beta with a guided dashboard, a user-selected data drive, experimental Windows 3D and verified GitHub app updates. See the [release guide and per-VM storage budget](docs/RELEASE_1.0_BETA1.md). Existing guest data locations are preserved.

## Android Emulator & Windows VM for Mac

**Free, open-source macOS app for Android emulation and Windows ARM64 virtual machines on Apple silicon.**

Developed by **PwnedG0blin** · macOS **14+** · **MIT license** · **1.0 Beta 1**

[Deutsch: vollständige Anleitung](README.de.md) · [Setup](LIES_MICH_ZUERST.md) · [Mac test builds](https://github.com/PwnedG0blin/OpenGuest/actions/workflows/macos.yml) · [Report an issue](https://github.com/PwnedG0blin/OpenGuest/issues)

Stratovo brings Android ARM64 and Windows ARM64 guest systems into a native Mac interface. Install Android APKs, use persistent guest storage, and open each guest in its own resizable player window. Only one guest runs at a time. System images, engines and drivers are set up separately.

## Interface language

Stratovo follows your preferred macOS language at launch. Override it under Setup → Language. Fourteen language folders are included: German, English, French, Spanish, Italian, Portuguese, Dutch, Polish, Turkish, Ukrainian, Arabic, Simplified Chinese, Japanese and Korean. Core controls are translated; technical text falls back to English, and some tool errors/logs retain their original language. Full technical translation is still in progress. Guest languages are independent.

## Android on Apple silicon

- Android 16 with Google Play is the default profile; Android 17 is optional.
- Install APK files and configure display resolution, density and input.
- Guest apps, accounts and data persist between sessions.
- Android graphics performance and app compatibility depend on the emulator and guest configuration. A 60 FPS target does not guarantee 60 game frames per second.

## Windows ARM64 virtual machines

- Install Windows using your own ARM64 ISO and an appropriate Windows license.
- Persistent virtual disks, ARM64 firmware, TPM support and optional Virtio drivers.
- Experimental Windows 3D through VirtIO / Neptune / DXMT in an independent test copy. The first build requires full Xcode and additional libraries; see the release guide.

## Install or build

Download the DMG from [GitHub Releases](https://github.com/PwnedG0blin/OpenGuest/releases), or run `bash scripts/build-app.sh` on an Apple-silicon Mac with Xcode command line tools. The output is `dist/Stratovo.app`.

The test app is ad-hoc signed, not Developer ID signed or notarized. See [signing information](SIGNIERUNG.md), [setup instructions](LIES_MICH_ZUERST.md) and [third-party licenses](THIRD_PARTY_NOTICES.md).

## Updating from Pixelkoje / OpenGuest

Stratovo was previously called Pixelkoje. This repository keeps its existing **OpenGuest** URL so downloads, issue links and update checks continue to work. Shut down both guest systems and quit the previous app before replacing it. Keep your selected data folder.

The bundle ID, existing settings keys, keychain service, Android AVD names, Windows machine identity and legacy storage paths are intentionally preserved. Existing virtual disks are not moved or recreated by this rename.

## Development and privacy

The application is a development test version. Native compilation, automated tests and a launch smoke test do not establish full guest or game compatibility. Stratovo itself has no telemetry; guest operating systems and separately installed components have their own network behavior. GitHub update checks are optional and off by default; no automatic app installation occurs.

Contributions: [CONTRIBUTING.md](CONTRIBUTING.md) · Security and local data: [SECURITY.md](SECURITY.md).

## Developer and support

Developed by **PwnedG0blin**. [GitHub Sponsors](https://github.com/sponsors/PwnedG0blin) · [Patreon](https://www.patreon.com/cw/PwnedG0blinApp) · [X](https://x.com/PwnedG0blin)

Copyright (c) 2026 PwnedG0blin and contributors. [MIT license](LICENSE). Voluntary sponsorship supports development; Stratovo remains free and without a subscription.
