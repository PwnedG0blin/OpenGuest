# Stratovo 1.0 Beta 2

Windows uses the existing Windows installation with 3D acceleration in the
Stratovo player. Ubuntu ARM is a new independent guest option.

- One **Windows** workspace replaces the normal/test-mode selector. The existing
  `Windows/windows.qcow2`, accounts, files, NVRAM, TPM and machine identity are reused.
- VirtIO / Neptune / DXMT continues to use Apple's Metal GPU. A bounded asynchronous
  Metal readback feeds the embedded player, keeping paste, keyboard and trackpad controls.
- Existing graphics runtimes need **3D-Player vorbereiten / aktualisieren** once.
  The update recompiles QEMU using the existing build; it keeps ANGLE, LLVM and guest disks.
- The player recognizes the known firmware logo and replaces its bitmap on screen.
  Persistent firmware stays unchanged. The player footer shows **Esc at startup: UEFI / BIOS**.
- Ubuntu 26.04.1 LTS ARM64: official ISO download with pinned SHA-256 verification,
  separate 64-GiB disk and NVRAM, installation and normal startup in the same player.
- CPU, memory, Windows network, setup media, Pro/local-account options and text input
  stay attached to the existing Windows session.
- Existing Android profiles, data folder, saved preferences and Keychain identity remain in use.

## Storage

| Guest / tools | Planning allowance |
| --- | --- |
| Android 16 | about 80 GiB |
| Android 17 | about 80 GiB extra, independent profile |
| Windows | configured virtual disk size + about 20 GiB |
| Windows 3D build tools | at least 30 GiB once; no second Windows disk required |
| Ubuntu ARM | about 80 GiB; 40 GiB free before installation, 6–8 GiB guest RAM |

## Upgrade

1. Shut down all guests and install the new app.
2. Open Windows and update the embedded 3D player once. Keep the data volume mounted.
3. Start the existing Windows. If needed, open **This PC → PKGRAPHICS → INSTALL_GRAPHICS.cmd**
   inside Windows, shut down and start Windows again.
4. Test files, account, display and paste. Previous `GraphicsLab/TestVM` data is retained;
   it is not merged automatically and must not be deleted before reviewing its contents.
5. Ubuntu is optional. Download, install, shut down, then choose **Ubuntu starten**.

## Validation and beta limits

Regression tests cover launch arguments, preserved source data, guest separation,
download integrity and logo matching. CI compiles the app and checks the Metal adapter
against the macOS SDK. These checks do not replace a live Windows/Ubuntu installation
or sustained 3D performance testing on an M4. The embedded 3D path remains experimental;
60 FPS and game compatibility are not guaranteed. Only common BGRA8/RGBA8 Metal scanouts
are supported by the first embedded adapter. New technical strings may use fallback text.

Developed by **PwnedG0blin**.
