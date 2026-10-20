# Architecture and boundaries

Native SwiftUI application, SwiftPM package, macOS 14+, ARM64. Core command plans and protocol helpers are separated from the UI. No shell executes user-provided filenames: Foundation `Process` receives executable paths and argument arrays. QEMU filenames in compound options use JSON blockdev descriptions.

## Android

The official emulator starts headlessly with ARM64 CPU acceleration required. Existing AVD user data and Quick Boot storage are reused. A separate one-time SDK script installs the official Google Play ARM64 image and creates a named AVD without `--force`.

ADB targets a chosen explicit emulator serial for every command. Once `sys.boot_completed` is 1, a checksum-verified scrcpy 4.0 server is pushed to that guest. An owned ADB forward provides two local channels: H.264 video and binary input. No screen-screenshot polling is used. The protocol is pinned because upstream explicitly considers it internal and version-specific.

The native player parses bounded 12-byte packet headers, converts H.264 Annex-B NAL units to length-prefixed samples and submits them to AVSampleBufferDisplayLayer. If backpressure requires dropping video, it waits for a fresh IDR frame to avoid decoding dependent frames against a lost reference. The 60-FPS setting is a target, not measured throughput. Encoder, decoder and graphics compatibility require hardware testing. There is no shared-texture or zero-copy Android GPU integration yet.

Google sign-in happens in Android. The app does not read account tokens, passwords, sync contents or app cloud saves. The OS stores its own account and app data in its persistent AVD. The UI only opens account, backup and Play Games screens and checks package presence.

## Windows

QEMU ARM `virt` + HVF, NVMe qcow2 disk, pflash code and persistent variables, swtpm 2.0 TIS and experimental VirtIO/Neptune/DXMT 3D through Metal. A per-VM advisory lock prevents concurrent use by two Stratovo instances. TPM storage is retained. The firmware must meet Windows' requirements; basic QEMU ARM firmware is not a substitute for a tested Secure-Boot-capable firmware pair.

Display, QMP and TPM sockets live in a short random directory with mode 0700. No VNC TCP listener is created. The embedded RFB client requests raw pixels and desktop resizing; buffers and message sizes are bounded. A local QMP command asks the guest to power down. A patched Cocoa backend exports Metal or OpenGL frames into a VNC-owned CPU surface without replacing the GPU scanout. One native Metal read is in flight; GL reads are limited to 60 per second and coalesce updates. No Windows audio device is configured yet.

A temporary setup ISO optionally selects the Pro image and provisions a user-chosen local administrator through supported Windows answer-file settings. Other first-run settings remain interactive. No static product key, automatic login, disk partition script or hardware-check bypass is included. The local password is in memory and the short-lived answer file; Windows' reversible answer-file encoding is not encryption. A private directory limits access. Normal cleanup removes the temporary medium, while Windows may retain its own setup files inside the guest. Unexpected process/system crashes can leave temporary files.

## Ubuntu ARM

Ubuntu Desktop ARM64 is downloaded from Canonical with pinned SHA-256 verification.
Its own 64-GiB QCOW2 disk, NVRAM and lock live under `Ubuntu`. It uses QEMU/HVF and
the same local RFB player, without attaching Android or Windows disks. Installation
mode attaches the ISO; normal starts omit it.

## File exchange

`Austausch` lives inside the selected data root. Native macOS SMB can expose it to
Windows and Ubuntu after user-controlled system setup; Stratovo does not enable
SMB or store Mac passwords. Android uses explicit ADB send/import commands with a
chosen emulator serial. Imports and sends use new subfolders, without destructive
synchronization. The UI distinguishes copying to Android from direct SMB access.
See [setup](DATEIAUSTAUSCH.md).

## Lifecycle

Each player owns its launched processes. UI status distinguishes engine availability, process launch and Android boot readiness. Probe commands have timeouts; regular log files avoid output-pipe deadlocks. Guest shutdown is requested before app termination. The confirmed emergency process-termination action may lose guest data and is not the normal shutdown path.

No automatic restart loop, data wiping, cloud reauthentication, privileged daemon or custom public network server is implemented. Optional folder access uses the user’s native macOS SMB configuration. Guest operating systems can access the internet when their network is enabled. Android's Google sync and Windows network settings remain OS-level decisions.

## Primary references

- Android acceleration: https://developer.android.com/studio/run/emulator-acceleration
- AVDs / official Google Play images: https://developer.android.com/studio/run/managing-avds
- ADB: https://developer.android.com/tools/adb
- scrcpy protocol: https://github.com/Genymobile/scrcpy/blob/master/doc/develop.md (the reviewed protocol documentation describes version 4.0; use matching release sources for maintenance)
- AVSampleBufferDisplayLayer: https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer
- RFB: https://www.rfc-editor.org/rfc/rfc6143
- QEMU ARM: https://www.qemu.org/docs/master/system/arm/virt.html
- QEMU TPM: https://www.qemu.org/docs/master/specs/tpm.html
- Windows local accounts: https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-useraccounts-localaccounts-localaccount
- Windows online-account screen: https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-oobe-hideonlineaccountscreens
- Google cloud saves: https://support.google.com/googleplay/answer/9275812
- Android backups: https://support.google.com/android/answer/2819582
