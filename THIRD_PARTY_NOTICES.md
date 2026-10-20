# External components

Stratovo's app source is MIT licensed, except the QEMU integration fragment described below. Engines and operating systems are installed separately and are not relicensed by Stratovo.

| Component | Role | Upstream / terms |
| --- | --- | --- |
| Android Emulator / SDK tools | ARM64 AVD execution, ADB | https://developer.android.com/studio/terms and component notices |
| Google Play system images | Google services and Play Store | Supplied through Google's SDK tools under their terms; not included here |
| scrcpy server 4.0 | Video capture and guest input bridge | https://github.com/Genymobile/scrcpy/releases/tag/v4.0 — Apache-2.0; exact server downloaded separately |
| QEMU | Windows ARM virtualization | https://www.qemu.org/ and its GPL/component notices |
| swtpm / libtpms | Persistent virtual TPM | https://github.com/stefanberger/swtpm and upstream license files |
| EDK II firmware | UEFI / Secure Boot capabilities | https://github.com/tianocore/edk2 and firmware-specific notices |
| Windows | User-installed guest OS | https://www.microsoft.com/software-download/windows11arm64 — separately licensed |
| Windows guest drivers | VirtIO network and additional guest support | https://docs.getutm.app/guest-support/windows/ — component-specific terms |
| Apple frameworks | Native UI, networking and video | Part of macOS; no Apple framework binaries redistributed |

If redistributing dependency binaries later, include their full applicable licenses, notices and source/source-offer obligations as required. The current archive includes none of their binaries, firmware, Google images or Windows media.

Product names are references to compatibility and architecture, not endorsements or affiliations.

Using a Google Play SDK image does not certify Stratovo as a Google-approved consumer emulator or grant a general GMS redistribution license. Review SDK/GMS terms before a public consumer release. The current route is a user-installed development AVD.


## UTM Windows Guest Tools (optional download)
Not bundled. Official ISO: https://getutm.app/downloads/utm-guest-tools-latest.iso
Documentation: https://docs.getutm.app/guest-support/windows/
Includes independently licensed guest drivers and utilities; their original licenses remain applicable. Download occurs only on user action to the selected data volume. No claim of UTM affiliation or complete SPICE support.

## Experimental Windows graphics lab

The optional graphics lab downloads and builds upstream sources pinned in `Packaging/GraphicsLab/sources.json`: UTM's QEMU, virglrenderer, libepoxy, DXMT and WebKit/ANGLE forks, LLVM, and the Windows VirtIO 3D drivers. Their original licenses and notices apply. Built runtimes and driver binaries are not included in this app release. Building or redistributing those components does not change their upstream licensing obligations.

The small `pkgconf-2.3.0.tar.xz` source archive is included to bootstrap pkg-config when needed. Its original `COPYING` file is retained inside that unmodified archive. Source: https://distfiles.ariadne.space/pkgconf/pkgconf-2.3.0.tar.xz

These components are developed by their respective upstream authors. Stratovo is an independent integration and is not affiliated with or endorsed by UTM, Microsoft, Google or Apple.

The display source fragments under `Packaging/GraphicsLab` (`*_frame.*.inc`, `embedded_bridge.m.inc` and its legacy copy) is licensed under GPL-2.0-or-later for integration into QEMU. The patch helper applies it to the pinned upstream source on the user’s Mac; no compiled QEMU binary is bundled. When redistributing a modified QEMU runtime, retain the upstream notices and comply with its corresponding-source obligations.

Ubuntu Desktop ARM64 is downloaded separately from Canonical. Ubuntu and its packages retain their upstream licenses: https://ubuntu.com/legal/intellectual-property-policy
