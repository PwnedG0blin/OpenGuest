# Pixelkoje 0.3.7 (formerly OpenGuest)

Windows installer media are now explicit read-only optical drives over USB-BOT. Remembered Windows setup credentials are verified by reading back the app’s own Keychain item, restored without an authentication prompt where possible, and retained in the masked fields after guest startup. If macOS requires access permission, the user can explicitly load the saved item; cancellation is reported clearly. The application does not save passwords in UserDefaults or diagnostics. CI checks optical-device initialization, not Windows OS installation.

The app, executable, player windows and installer are now named Pixelkoje. Existing storage pointers, bundle ID, settings keys, Keychain service, Android AVD names and virtual hardware serials remain unchanged so this release reuses existing installations. Existing data folders such as `/Volumes/Extern/OpenGuest` are not renamed or copied; new data folders default to `Pixelkoje`. The source repository retains its existing URL.

Windows startup fix in **0.3.6**: TPM stays enabled with persistent state, but its optional physical-presence interface (PPI) is disabled. This avoids QEMU #4587's `HV_BAD_ARGUMENT` during device initialization with HVF on Apple Silicon. This does not disable Secure Boot checks, bypass Windows requirements or erase VM data. The installed UEFI firmware must still support the intended Windows configuration. Source: https://gitlab.com/qemu-project/qemu/-/work_items/4587 . CI now initializes a real swtpm + QEMU TPM under TCG and, where the runner provides it, HVF. It does not test a complete Windows installation.

Current test build: **0.3.7**. Opening the app shows the main window only; guests require an explicit Start action. Starting Android or Windows opens its own resizable player window. The Android page can also open Google's account chooser in the normal external Mac browser; this does not sign the Android guest in automatically.

# Pixelkoje

Native macOS test player for Android ARM64 and Windows ARM64, MIT licensed, free and without subscription.

Version 0.2 asks for a data folder before guest setup. It can copy and SHA-256 verify legacy default SDK/AVD/Windows/runtime/log directories and explicitly selected ISO files from Downloads, redirect legacy paths, retain originals, and remove only receipt-backed unchanged backups after user review. Missing data drives block guest launches and downloads rather than falling back internally. Nine dedicated storage migration tests cover recovery, conflicts, lost destinations, changed backups, ISO scope and persistence. Native CI supplies the executable test app.

Read **LIES_MICH_ZUERST.md** for the external SSD migration and cleanup steps. macOS 14+, Apple Silicon. Guests, firmware, Google sign-in, driver integration, OOBE and performance remain integration-test work. Engines and OS images are not bundled. Windows ARM64 ISO and separate UTM ARM64 guest-tools ISO are selected independently. Windows 11 requires appropriate firmware and a separate license. Not Developer ID signed/notarized.

Source: https://github.com/PwnedG0blin/OpenGuest

0.2.1 fixes migration verification: every source file is SHA-256 checked, while additional target files such as AppleDouble/Finder metadata are preserved. Missing or changed payload still blocks migration. Detailed errors name the affected path; original-change detection protects against concurrent writers. Three regression tests cover target extras, invalid payload and interrupted migration recovery.

0.2.2 improves the storage setup dialog: 16-point readable body/status/path text, high contrast status cards, explicit error heading, larger controls and scrollable long messages. Copy progress remains readable while only actions are disabled.
