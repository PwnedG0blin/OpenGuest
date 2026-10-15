# External components

OpenGuest's own source is MIT licensed. Engines and operating systems are installed separately and are not relicensed by OpenGuest.

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

Using a Google Play SDK image does not certify OpenGuest as a Google-approved consumer emulator or grant a general GMS redistribution license. Review SDK/GMS terms before a public consumer release. The current route is a user-installed development AVD.
