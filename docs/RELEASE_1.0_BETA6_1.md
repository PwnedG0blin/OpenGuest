# Stratovo 1.0 Beta 6.1

The native Windows player now remembers its normal window size and position.
After a monitor is disconnected, restored windows are moved and limited to a
visible screen. Full-screen state is not restored by this change.

Graphics preparation now includes the window persistence resources and displays
its progress and errors automatically. The three native window callbacks access
the window through the Cocoa view. An exact-source migration accepts and repairs
the earlier failed player build without deleting the graphics folder.

Existing installations need one **3D-Player vorbereiten / aktualisieren** run.
ANGLE and LLVM builds are reused. Existing Windows disks and installed guest
drivers are retained. The developer's user reported the private Build 1015 working.

Regression checks cover staged resource dependencies, earlier player source
migration, and a macOS compile test of the real window callbacks alongside the
preferences round-trip test across separate processes.

This public release includes the public changes only. Private compatibility
extensions and private firmware assets are not part of this repository.

Developed by **PwnedG0blin**.
