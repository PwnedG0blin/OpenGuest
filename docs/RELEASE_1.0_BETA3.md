# Stratovo 1.0 Beta 3

Repairs code defects in the embedded Windows 3D display and adds file exchange
for Android, Windows and Ubuntu. Existing guest disks, accounts and saved data
remain in their selected data folder.

## Windows Arm: direct graphics by default

Windows Arm now starts in its own Cocoa/Metal graphics window, using the existing
Neptune/DXMT runtime and Windows installation. This avoids the GPU readback and
VNC frame copies introduced by embedding. A user reported severe stalls when
opening apps in the embedded view; the direct path is restored as the default.
Paste text, file exchange, firmware keys and shutdown stay in Stratovo's Windows
controls. The embedded player is an explicit experimental option, changeable
while Windows is shut down. Native-window scrolling and fullscreen are handled
by the graphics window rather than Stratovo's embedded-player controls.

Existing complete graphics runtimes can use direct output without rebuilding.
Only the optional embedded mode requires player revision 3.

## Optional embedded display repair

- Adds a classic OpenGL readback path alongside Metal. Beta 2 only exported
  native Metal scanouts, which could leave a guest's GL output invisible.
- Gives VNC its own CPU presentation surface. A GPU scanout is no longer resized
  or fed back through graphics callbacks when exporting a frame to the player.
- Corrects the vertically inverted OpenGL image when exporting GPU rows to VNC.
- Handles display size changes and VNC reconnects independently of the guest GPU.
- Updates only the existing QEMU build. ANGLE, LLVM and guest images are reused.
  For embedded output, existing Beta 2 runtimes need
  **3D-Player vorbereiten / aktualisieren** once.
  A previous QEMU program file is retained under `GraphicsLab/PlayerBackup-v1`.

These are confirmed code defects, not a confirmed diagnosis of every black screen.
If Windows remains black after updating, include its latest session log in a
report. New logs distinguish the first OpenGL or Metal frame.

## File exchange

- **Dateiaustausch / File exchange** in the sidebar, dashboard, embedded players
  and Windows controls.
- An `Austausch` folder inside the selected data folder.
- Windows and Ubuntu: direct folder access through native macOS SMB after a guided,
  one-time setup. No sharing service is enabled automatically.
- Android: selected-file sending and importing from Downloads/Stratovo-Austausch
  through the existing ADB connection. New subfolders preserve earlier copies.
- No automatic deletion synchronization or virtual-disk sharing.

[Setup, addresses and limitations](DATEIAUSTAUSCH.md).

## Storage and upgrade

| Guest / tools | Planning allowance |
| --- | --- |
| Android 16 | about 80 GiB |
| Android 17 | about 80 GiB extra, independent profile |
| Windows | configured virtual disk size + about 20 GiB |
| Windows 3D tools | at least 30 GiB once; no second Windows disk required |
| Ubuntu ARM | about 80 GiB; 40 GiB free before installation; 6–8 GiB guest RAM |
| File exchange | additional space for your files; Android transfers create copies |

Shut down guests, replace the app and start the existing Windows with direct
graphics selected. Keep old VM data and the previous test copy until their files are reviewed.
[Cleanup guide](AUFRAEUMEN.md).

## Validation

The CPU-frame and VNC adapter code is exercised under address and undefined-behavior
sanitizers for resizing, GPU-buffer preservation, color order, vertical orientation
and reconnects. CI compiles the exact Metal and OpenGL fragments against the macOS
SDK and runs the app's regression tests. These checks do not establish a successful
Windows/Ubuntu boot or sustained GPU performance on an M4. The graphics path remains
experimental. Metal readback currently supports BGRA8/RGBA8 scanouts.

Developed by **PwnedG0blin**.
