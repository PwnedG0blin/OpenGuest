# Validation status – 2026-10-15

## Performed in the authoring environment

- Swift tree-sitter syntax parse of the source files; this does not type-check Apple APIs or replace compilation.
- Bash syntax checks for setup and build scripts.
- XML/plist and CI YAML structural checks.
- Static checks for persistent guest storage, explicit ADB serials, private Windows sockets and absence of wipe-data flags.
- Mocked streaming setup-script exercise: successful verified download, wrong digest rejected, missing digest rejected. No real upstream binary was executed in this environment.

## Not performed

There is no Swift toolchain or macOS SDK in the Linux authoring environment. Native ARM64 compilation and all 13 Swift tests have now passed in GitHub Actions run 38802745791. Still not performed: Mac UI inspection, actual Android/Windows boot, Google login, app-cloud-sync test, Windows Pro/local-account setup, firmware Secure Boot check, audio test, crash/stress test or performance benchmark has been completed. The source must not be described as end-to-end tested.

## Mac acceptance tests before a release

1. Run `swift test` and the Release build on Apple Silicon; fix all failures. Exercise failed/missing engine paths and log errors without hanging the app.
2. Prepare a Google Play AVD; open Stratovo and verify Android starts directly in its own player. Confirm the displayed service status and Google login in the guest.
3. Install a known test APK; confirm that a connected physical phone or a second emulator receives no APK or input commands.
4. Install Play Games; log in to a game that actually supports Google cloud saves. Verify the same test save is restored on another device using the same game/account. Do not infer cloud support merely from package presence.
5. Install an APK, create local data, sign in; shut down and reopen at least 10 times. Verify all account/app state survives cold and Quick Boot paths. Never use wipe-data as a repair step.
6. Measure a moving Android workload with the stream counter and Instruments, then independently measure frame presentation and input latency. Compare like-for-like with MuMu on the same M4, app, resolution, RAM and CPU. No 60-FPS claim until measured. Check idle counter behavior and decoder recovery.
7. Use a tested ARM64 UEFI/vars pair meeting Windows 11 requirements. Install from Microsoft's Arm64 ISO. Confirm Pro edition, normal setup prompts and successful local-account creation with the chosen credentials. Confirm no Microsoft sign-in is required with the local-account option.
8. Load ARM64 network drivers; enable guest networking if needed; confirm Windows Update and normal app installation. Verify that turning off install mode boots from the existing virtual disk.
9. Shut Windows down and relaunch; verify disk, UEFI and TPM state persists, including across host restarts. Never remove TPM storage to fix a boot error.
10. Start a second instance against the same Windows disk; verify the lock rejects it without altering disk/TPM files. Confirm socket directory permissions, and that VNC is not listening on TCP.
11. Interrupt the streaming client and stop the guest; verify all owned ADB forwards, sockets and child processes are cleaned up, without touching unrelated emulators or user data.
12. Verify graceful shutdown from both players and Cmd-Q behavior. Emergency stop must warn about unsaved guest data. Stress-test long sessions, low disk space and log growth.
13. Complete license review, native code review, Developer ID signing, notarization and Gatekeeper verification before shipping a public `.app`.

The first macOS CI run has passed compilation and all 13 unit tests. Its unit tests cover resource bounds, argument handling, serial targeting, persistence flags, XML account settings and bounded protocol parsing, but cannot validate a real guest OS.
