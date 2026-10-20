# Stratovo 1.0 Beta 4

The direct Windows Arm graphics window can now be resized freely and scales the
whole guest image when enlarged, maximized or placed in fullscreen. The native
Metal path remains the default, without VNC frame copying.

- GL and Metal layers fit the viewport while preserving aspect ratio.
- Guest display changes no longer resize the user's macOS window.
- Mouse and cursor coordinates use the same fitted image rectangle.
- Metal drawable size stays at guest resolution; Core Animation scales on the GPU.
- Live resize reports the final size to the guest, avoiding intermediate mode requests.
- Windows Arm / Stratovo titles persist on mouse capture and release.
- An exact known firmware bitmap is covered with a Windows-style mark and an Esc /
  UEFI hint in presentation only. Guest pixels, firmware, keys, menus and errors
  remain unchanged. Unknown artwork is left visible.

After replacing the app, shut down Windows and choose **Windows Arm → 3D-Player
vorbereiten / aktualisieren** once. Player revision 4 rebuilds only existing QEMU;
ANGLE, LLVM, guest disks, TPM, firmware and identity are retained.

The file exchange instructions from Beta 3 remain. **SSD_Uebersicht.command** only
lists files and sizes. Remove old build packages after testing the new player;
keep current VM data, backups and graphics runtime/source files.

Validation exercises the actual native geometry under ASan/UBSan and compiles/runs
native layer and boot-overlay methods with AppKit. These are presentation tests,
not a live Windows boot, Steam download or M4 performance benchmark.

Developed by **PwnedG0blin**.

## Steam download comparison (optional)

Under **Windows Arm → Steam-Download testen**, the **Windows-Schreiblimit** is
**Off** by default. Shut down Windows, select **40 MiB/s**, then start Windows
and resume the same download for comparison. Available limits: 20, 40, 80 MiB/s.
The limit affects **all writes to the Windows system disk**, not just Steam;
installations may take longer. Changes apply on the next Windows start. Return
to **Off** before testing game performance, or if responsiveness does not improve.
This is an experiment, not a measured Steam or gaming performance improvement.
It does not alter the disk image format, cache or flush policy.
