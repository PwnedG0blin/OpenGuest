# OpenGuest

Free, open-source macOS guest players for Apple Silicon. Native SwiftUI interface, separate Android and Windows workspaces, no app subscription. **Version 0.1.0 is an unverified source prototype, not a production emulator release.**

German setup guide: [LIES_MICH_ZUERST.md](LIES_MICH_ZUERST.md).

## Implemented source paths

| Android Player | Windows Player |
| --- | --- |
| Existing ARM64 AVD, automatic boot | Persistent 80-GiB qcow2 disk, NVMe |
| Official Google Play image setup via SDK tools | User-supplied Windows 11 Arm64 ISO |
| APK install with explicit emulator serial | Pro image selection, optional local user |
| Play Games, account sync and backup settings | Persistent UEFI variables and TPM 2.0 |
| Pinned scrcpy 4.0 H.264 transport and controls | Minimal embedded RFB 3.8 player |
| Native AVSampleBufferDisplayLayer output | Private Unix sockets for display and QMP |
| 60-FPS stream target; not benchmarked | HVF CPU acceleration; no 3D acceleration |

Guest data is persistent. No reset, disk reformat or snapshot-discard feature is exposed. Cloud sync remains application-dependent. Only one guest runs at a time in this prototype.

## Build

Apple Silicon Mac, macOS 14+, Swift 5.9+ / Xcode required. No third-party Swift packages.

```sh
swift test
swift build
```

`Start.command` runs tests, compiles and packages a locally ad-hoc-signed `.app`. It does not create a Developer ID signature or notarization. No Mac security settings are disabled.

Android's SDK and Google Play image are installed separately. Streaming setup downloads the exact upstream scrcpy server and verifies its upstream release digest. Windows requires external QEMU, swtpm, a suitable Secure-Boot-capable ARM64 firmware/variable pair, optional ARM64 drivers and a Windows license. These components are not included in the source archive.

## Status and validation

See [docs/TESTPLAN.md](docs/TESTPLAN.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Syntax and static package checks were possible in the authoring environment. **Native compilation, the Swift test suite and both guest runtime paths have not been executed.** The macOS Actions workflow is provided but has not been run in a public repository.

The UI and source contain complete first implementations of these paths; API compatibility and real guest behavior still require Mac testing. In particular, Windows firmware selection, setup answer-file pickup, OOBE local-account creation and Google services must be validated before claiming working end-to-end support.

The prepared `Build macOS test app` Actions workflow uses an Apple Silicon macOS runner, runs tests, builds the app bundle and uploads `OpenGuest-macOS-AppleSilicon.app.zip` only if these steps succeed. No build has been dispatched. Its resulting binary would still require external engines/guest setup and native integration testing; it would not be a complete, notarized consumer installer.

## License and distribution

OpenGuest's own code: [MIT](LICENSE). External components: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No MuMu, BlueStacks or VMware code/assets are included. Their exact Mac graphics implementations have not been established from the public material reviewed.

The source archive can be shared freely under MIT. No public repository or hosted release has been created by this deliverable. Before a public binary release: run the tests, review dependency versions, complete native runtime tests, sign with Developer ID and notarize.
