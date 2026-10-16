# Pixelkoje 0.3.11: paste Mac text into Windows Setup and applications

The Windows player offers “Text einfügen …” and Command+V in the focused display. Only that explicit action reads plain text from the Mac pasteboard into an editable preview. Choose the keyboard layout used inside Windows (German or US); the physical Mac keyboard does not determine it. A fully validated plan types the text using paced QMP physical-key chords, without a guest clipboard agent or shared network service. QEMU releases each chord after a bounded hold time, including when the sender is canceled or disconnected. Command+V is consumed locally without sending a Windows key that could open Start. Other Command chords retain their prior guest behavior.

Caps Lock must be off inside Windows. The supported character sets are printable US ASCII, plus German layout characters and selected German dead-key accents. Unsupported characters and inputs longer than 4096 characters reject the whole plan before sending. Trailing line breaks are removed so a copied command is not submitted; internal line breaks require an explicit toggle because they generate Enter. Transfer progress and cancel are available, and copied contents are never persisted or logged. This is Mac-to-Windows text entry, not bidirectional clipboard or file transfer. Native tests cover shortcut routing, actual QMP requests and cancellation; a real running QEMU accepts representative chords without a Windows OS image. Target Windows field behavior still needs confirmation on the user's Mac.

# Pixelkoje 0.3.10: Windows function keys and setup console shortcut

Maps macOS F1–F12 hardware codes to RFB function-key symbols instead of sending AppKit's private-use text as Unicode. The Windows player adds an explicit setup-console button that sends a complete Shift+F10 press/release chord without depending on the Mac's media-key settings. The button reports that the shortcut was sent; whether Windows opens the console depends on the guest's current screen and policy. A local RFB peer regression test records the production client's actual shortcut bytes, including modifier releases. This release does not change Windows accounts, organizational enrollment, VM identity, firmware, disks, or setup media. An unexpected organization sign-in must be diagnosed separately.

# Pixelkoje 0.3.9: explicit Windows DVD selection and display startup diagnostics

Adds a prominent manual DVD-ISO picker with a persistent full path and readable-file/size validation before install startup. Choosing a DVD enables installation mode. File checks do not certify architecture or bootability. QMP query-status/query-block verify the actual running VM and attached read-only installer CD after launch. VNC now waits for the local socket and bounds handshake and first-frame waits, with specific visible progress/errors instead of an indefinite startup overlay. A native Swift player test connects the actual app RFB client to QEMU's framebuffer without an OS image. Full Windows installation on the target Mac remains unverified; no VM disks or UEFI variables are reset.

# Pixelkoje 0.3.8: Android performance profiles

Adds reversible guest display-size/density overrides (smooth, balanced, native), bounded stream sizes/bitrates and 30/60 FPS targets without changing the existing settings JSON schema. Renderer evidence distinguishes forced software rendering from a recognized Apple GPU. A one-time default prefers host GPU over auto; explicit software preference is preserved. Decoder submission waits up to 60 ms for backpressure before flushing/reference recovery, with reset-generation and cancellation checks. Received video FPS and submitted decoder FPS are labelled separately, neither as game FPS nor as displayed-frame measurements. These changes do not replace the emulator or remove its forced-software limitation. Real game performance must be compared on the user's Mac.

# Pixelkoje 0.3.7 (formerly OpenGuest)

Windows installer media are now explicit read-only optical drives over USB-BOT. Remembered Windows setup credentials are verified by reading back the app’s own Keychain item, restored without an authentication prompt where possible, and retained in the masked fields after guest startup. If macOS requires access permission, the user can explicitly load the saved item; cancellation is reported clearly. The application does not save passwords in UserDefaults or diagnostics. CI checks optical-device initialization, not Windows OS installation.

The app, executable, player windows and installer are now named Pixelkoje. Existing storage pointers, bundle ID, settings keys, Keychain service, Android AVD names and virtual hardware serials remain unchanged so this release reuses existing installations. Existing data folders such as `/Volumes/Extern/OpenGuest` are not renamed or copied; new data folders default to `Pixelkoje`. The source repository retains its existing URL.

Windows startup fix in **0.3.6**: TPM stays enabled with persistent state, but its optional physical-presence interface (PPI) is disabled. This avoids QEMU #4587's `HV_BAD_ARGUMENT` during device initialization with HVF on Apple Silicon. This does not disable Secure Boot checks, bypass Windows requirements or erase VM data. The installed UEFI firmware must still support the intended Windows configuration. Source: https://gitlab.com/qemu-project/qemu/-/work_items/4587 . CI now initializes a real swtpm + QEMU TPM under TCG and, where the runner provides it, HVF. It does not test a complete Windows installation.

Current test build: **0.3.11**. Opening the app shows the main window only; guests require an explicit Start action. Starting Android or Windows opens its own resizable player window. The Android page can also open Google's account chooser in the normal external Mac browser; this does not sign the Android guest in automatically.

# Pixelkoje

Native macOS test player for Android ARM64 and Windows ARM64, MIT licensed, free and without subscription.

Version 0.2 asks for a data folder before guest setup. It can copy and SHA-256 verify legacy default SDK/AVD/Windows/runtime/log directories and explicitly selected ISO files from Downloads, redirect legacy paths, retain originals, and remove only receipt-backed unchanged backups after user review. Missing data drives block guest launches and downloads rather than falling back internally. Nine dedicated storage migration tests cover recovery, conflicts, lost destinations, changed backups, ISO scope and persistence. Native CI supplies the executable test app.

Read **LIES_MICH_ZUERST.md** for the external SSD migration and cleanup steps. macOS 14+, Apple Silicon. Guests, firmware, Google sign-in, driver integration, OOBE and performance remain integration-test work. Engines and OS images are not bundled. Windows ARM64 ISO and separate UTM ARM64 guest-tools ISO are selected independently. Windows 11 requires appropriate firmware and a separate license. Not Developer ID signed/notarized.

Source: https://github.com/PwnedG0blin/OpenGuest

0.2.1 fixes migration verification: every source file is SHA-256 checked, while additional target files such as AppleDouble/Finder metadata are preserved. Missing or changed payload still blocks migration. Detailed errors name the affected path; original-change detection protects against concurrent writers. Three regression tests cover target extras, invalid payload and interrupted migration recovery.

0.2.2 improves the storage setup dialog: 16-point readable body/status/path text, high contrast status cards, explicit error heading, larger controls and scrollable long messages. Copy progress remains readable while only actions are disabled.
