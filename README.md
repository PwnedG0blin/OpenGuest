Entwickelt von **PwnedG0blin** · Copyright (c) 2026 PwnedG0blin.

Projektentwicklung und Lizenzen: [AUTHORS.md](AUTHORS.md) · [LICENSE](LICENSE).

# Pixelkoje 0.3.19: S26 Ultra display preset and portrait player window

Android display controls offer a 1440×3120 portrait preset with adjustable 500 dpi logical scaling. Samsung lists this resolution and roughly 500 physical ppi; our 500 dpi is an app preset, not a claim about Samsung's default Android logical density. This changes display settings only; it does not install Samsung firmware. The player adds explicit Fit and Phone window actions. The latter uses the current stream aspect ratio and available screen, re-measures wrapped controls, and enables fit. In full screen it enables fit without leaving full screen. AppKit immediately updates the video layer frame after geometry changes; no black pixels inside a game are cropped.

# Pixelkoje 0.3.17: repair an offline Android connection

The Android page adds an explicit repair action while both guests are off. It restarts the selected SDK's ADB server (kill-server, then start-server, with bounded timeouts), then enables cold boot. The button explains that other ADB debugging connections are also disconnected. It does not delete guest data, change the graphics profile or start a guest automatically. Failure leaves cold-boot settings unchanged and displays the command error. No automatic global ADB restart is performed.

# Pixelkoje 0.3.16: paste Mac text into Android and optional Windows graphics

The Android player now offers “Text einfügen …” and Command+V on the guest display. Explicitly opening the dialog reads plain text from the Mac clipboard. Review/edit it, then confirm to transfer UTF-8 text with scrcpy 4.0 SET_CLIPBOARD and its paste flag. The player adds no Enter, trims trailing line breaks and requires explicit approval of internal line breaks. Input is limited to 64 KiB; text is never written to logs or settings. This is a one-way user action, not automatic clipboard synchronization. The destination Android field must be focused; individual apps can block paste. Transport errors keep the dialog open; successful sending does not confirm acceptance by an Android app.

Windows graphics can be explicitly changed while the VM is off. Existing VMs retain ramfb basic graphics by default. Install the ARM64 display driver from the guest-tools CD inside Windows before choosing Virtio-GPU. The preferred 16:9 mode (1280×720, 1920×1080 or 2560×1440) is a monitor hint; modes/scaling depend on the installed guest driver. If the screen stays black, shut the VM down and return to basic graphics. This option provides 2D display, not 3D acceleration. Settings are remembered per data folder. Tests check launch arguments and real QEMU device acceptance under TCG; Windows guest-driver behavior requires verification on the target Mac.

# Pixelkoje 0.3.15: trackpad scrolling and display controls

The native player now handles AppKit scroll-wheel events, including precise two-finger motion and macOS momentum. AppKit already applies the natural-scroll preference; the player does not invert it again. Android receives scrcpy 4.0 fractional vertical/horizontal scroll messages at the guest coordinate. Windows accumulates small vertical deltas into bounded RFB wheel steps and sends every press/release pair together while preserving held buttons. QEMU's current VNC/USB-tablet path has no horizontal wheel support; Windows scrolling remains wheel-based rather than pixel scrolling. No global input monitor or Accessibility permission is used.

Both player windows can fit the image to the window or zoom from 25–300%, with a saved setting per guest type. At 100%, one received framebuffer pixel maps to one Mac backing pixel. Scrollbars pan an enlarged image; trackpad scrolling remains guest input. Pointer mapping uses the same centered/cropped image geometry. Momentum remains anchored to the control where the gesture began; cancel, focus loss, display resize and detach clear scroll state.

Android can use a custom even pixel width/height and DPI, applied live after boot or on its next start. Values are bounded and previous display overrides remain available for rollback if applying fails. Restore selects the physical display and density. Higher-resolution guests can still be downscaled by the chosen streaming profile. Windows has a button that sends Windows+I; actual guest resolution/text scaling is chosen under System > Display from the modes its installed driver offers. Player zoom does not change Windows display modes or install a new graphics driver. VM disks, UEFI variables, TPM and accounts are retained.

Regression tests cover fractional motion, reversal/reset, scrcpy's pinned 21-byte scroll packet, Retina/letterbox/zoom coordinate geometry, custom Android bounds/rollback, native AppKit event delivery and actual RFB wheel bytes received by a local peer. Full target-device gesture feel and guest resolution choices still require manual verification.

# Pixelkoje 0.3.14: stable per-VM Windows hardware identity and ISO verification

New VMs receive a persistent UUID, SMBIOS/NVMe serial and locally administered unicast MAC before disk creation. Existing disks retain the legacy identity until the user explicitly opts in while the VM is off. The prior identity is saved with a validated reversible change record in the selected Windows/Machine folder; repeat clicks and rollback/reapply reuse the same identity. The disk, UEFI variables and TPM are not rewritten. Identity changes may affect activation or BitLocker; the UI explains this before applying them. A session lock prevents changes while another player uses the VM. Damaged/missing identity files inside an existing Machine folder fail closed instead of regenerating identifiers. QMP confirms the actual running UUID in the combined diagnostic report.

The fixed legacy serial and absent per-VM UUID were concrete launcher defects. They are a plausible source of unintended Autopilot matching, not a proven cause of a particular tenant assignment. This update does not delete Windows policies, cached Autopilot data, cloud registrations or accounts, and does not claim to remove an existing company sign-in. The guest's resulting setup must still be checked. Secure Boot support is explicitly unverified; no new firmware or requirement bypass is included.

“Vorhandenes Windows starten” explicitly selects the saved disk instead of the installer DVD. App launch prefers an existing saved disk, including when upgrading from a version that kept installation mode enabled. An explicitly chosen DVD start applies once: after QEMU launches, disk boot is saved for the next launch while the ISO path remains available. This does not reset or reinstall the existing disk. “ISO mit Microsoft-Prüfsumme vergleichen” reads the selected ISO with a 1 MiB streaming SHA-256 buffer and compares it with Microsoft's German 26H2 ARM64 reference from https://www.microsoft.com/de-de/software-download/windows11arm64 (checked 2026-10-16). A mismatch is reported as an unknown/different image, not automatically as corruption. No ISO download or copy is performed by this check.

# Pixelkoje 0.3.13: developer credit and profile links

The sidebar credits PwnedG0blin and provides explicit links to the developer’s X profile and Patreon page. Clicking a link opens it in the Mac’s browser. Both appearances use readable teal links; no profile page is loaded automatically.

# Pixelkoje 0.3.12: a clearer paste dialog in the app’s teal style

The Windows paste preview now uses Pixelkoje’s teal accents, branded header, a tinted editable text card, a separate keyboard-layout card and a prominent “In Windows einfügen” action. System light/dark appearance is respected and the content scrolls while the action row stays visible. Validation, line-break opt-in and text-transfer behavior are unchanged. `scripts/preview-windows-paste.sh` renders the production view with an in-memory model in light/dark appearance for visual review; it does not start a guest or access user clipboard, settings or credentials.

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

Current test build: **0.3.19**. Opening the app shows the main window only; guests require an explicit Start action. Starting Android or Windows opens its own resizable player window. The Android page can also open Google's account chooser in the normal external Mac browser; this does not sign the Android guest in automatically.

# Pixelkoje

Native macOS test player for Android ARM64 and Windows ARM64, MIT licensed, free and without subscription.

Version 0.2 asks for a data folder before guest setup. It can copy and SHA-256 verify legacy default SDK/AVD/Windows/runtime/log directories and explicitly selected ISO files from Downloads, redirect legacy paths, retain originals, and remove only receipt-backed unchanged backups after user review. Missing data drives block guest launches and downloads rather than falling back internally. Nine dedicated storage migration tests cover recovery, conflicts, lost destinations, changed backups, ISO scope and persistence. Native CI supplies the executable test app.

Read **LIES_MICH_ZUERST.md** for the external SSD migration and cleanup steps. macOS 14+, Apple Silicon. Guests, firmware, Google sign-in, driver integration, OOBE and performance remain integration-test work. Engines and OS images are not bundled. Windows ARM64 ISO and separate UTM ARM64 guest-tools ISO are selected independently. Windows 11 requires appropriate firmware and a separate license. Not Developer ID signed/notarized.

Source: https://github.com/PwnedG0blin/OpenGuest

0.2.1 fixes migration verification: every source file is SHA-256 checked, while additional target files such as AppleDouble/Finder metadata are preserved. Missing or changed payload still blocks migration. Detailed errors name the affected path; original-change detection protects against concurrent writers. Three regression tests cover target extras, invalid payload and interrupted migration recovery.

0.2.2 improves the storage setup dialog: 16-point readable body/status/path text, high contrast status cards, explicit error heading, larger controls and scrollable long messages. Copy progress remains readable while only actions are disabled.

## Android 16, Android 17 und Updates

Android 16 mit Google Play ist der Standard. Vorhandene passende Profile werden wiederverwendet; Nutzerdaten werden bei der Einrichtung nicht überschrieben. Neue Profile erhalten 64 GiB. Unter „Downloads und Einrichtung“ lässt sich Android 17 als separates Profil installieren.

Stable ist voreingestellt. Beta, Dev und Canary schließen zusätzliche von Google angebotene SDK-Revisionen ein. Eine tägliche Updateprüfung beim Öffnen lädt nichts herunter. Optional kann das gewählte Systemabbild vor jedem Android-Start aktualisiert werden. Updates erfolgen nur bei ausgeschalteten Gästen; danach wird ein Kaltstart verwendet. Ein Wechsel der Android-Hauptversion erfordert ein eigenes Profil. Dies ist keine Pixel-Beta-Registrierung und garantiert nicht, dass jede Pixel-Beta als Google-Play-ARM64-Emulatorabbild verfügbar ist.

Für die Bereinigung das funktionierende Android 16 auswählen, alle Emulatoren beenden und unter „Alte Android-Profile und Daten bereinigen“ die Liste erstellen. Die Löschaktion entfernt ausschließlich die aufgelisteten anderen Profile im gewählten Datenordner, nicht mehr benötigte andere SDK-Systemabbilder und erkannte Android-15-Sicherungen aus der Speichervergrößerung. Apps, Konten und Spielstände dieser alten Profile sowie diese Sicherungen werden endgültig gelöscht. Das gewählte Android 16, Windows, Installationsmedien und andere Sicherungen bleiben erhalten. Extern referenzierte Systemabbilder werden vorsichtshalber behalten. Die App löscht beim Start nichts automatisch.

### Android-Bildübertragung

Die Stream-Warteschlange ist nach Bildanzahl, Datenmenge und Zeitspanne begrenzt. Bei Rückstau werden veraltete H.264-Referenzketten verworfen und erst ab einem neuen Schlüsselbild wieder angezeigt. Empfang und Decoder-Zuführung sind getrennt; FPS-Anzeigen werden sekündlich aktualisiert, auch wenn keine neuen Bilder eintreffen. „Anzeige neu verbinden“ startet nur den Videostream neu. Android und laufende Downloads werden dabei nicht neu gestartet.

Der bewährte Modus „Mac-GPU bevorzugen“ bleibt Standard. Optional lässt sich Vulkan für einen OpenGL-ES-Kompatibilitätstest ausschalten. Dies ist kein neuer BlueStacks- oder MuMu-Renderer und garantiert keine konstante Spielbildrate. Hohe Android-Auflösungen, Spiele, Encoder und Gastlast können weiterhin die Bildrate begrenzen.

Trackpad im Player: Scrolltempo für Android und Windows getrennt von 10 bis 200 Prozent einstellen (Vorgabe 50 Prozent). Trackpad-Nachlauf kann separat ein- oder ausgeschaltet werden; ausgeschaltet werden die Nachlaufereignisse des Macs nicht weitergegeben. Änderungen wirken sofort und werden gespeichert. Die natürliche Scrollrichtung folgt macOS.

Android bietet zusätzlich „Wischen wie am Handy“: Zwei Trackpad-Finger erzeugen Touch-Down/Move/Up im Gast. Bei Fokusverlust, Moduswechsel oder Abbruch wird die Berührung beendet. Ausschalten verwendet wieder Scrollrad-Ereignisse. Android-Apps können eigene Gesten und eigenen Nachlauf verwenden.
