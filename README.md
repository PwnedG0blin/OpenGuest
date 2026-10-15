# OpenGuest 0.2.1

Native macOS test player for Android ARM64 and Windows ARM64, MIT licensed, free and without subscription.

Version 0.2 asks for a data folder before guest setup or auto-start. It can copy and SHA-256 verify legacy default SDK/AVD/Windows/runtime/log directories and explicitly selected ISO files from Downloads, redirect legacy paths, retain originals, and remove only receipt-backed unchanged backups after user review. Missing data drives block guest launches and downloads rather than falling back internally. Nine dedicated storage migration tests cover recovery, conflicts, lost destinations, changed backups, ISO scope and persistence. Native CI supplies the executable test app.

Read **LIES_MICH_ZUERST.md** for the external SSD migration and cleanup steps. macOS 14+, Apple Silicon. Guests, firmware, Google sign-in, driver integration, OOBE and performance remain integration-test work. Engines and OS images are not bundled. Windows ARM64 ISO and separate UTM ARM64 guest-tools ISO are selected independently. Windows 11 requires appropriate firmware and a separate license. Not Developer ID signed/notarized.

Source: https://github.com/PwnedG0blin/OpenGuest

0.2.1 fixes migration verification: every source file is SHA-256 checked, while additional target files such as AppleDouble/Finder metadata are preserved. Missing or changed payload still blocks migration. Detailed errors name the affected path; original-change detection protects against concurrent writers. Three regression tests cover target extras, invalid payload and interrupted migration recovery.
