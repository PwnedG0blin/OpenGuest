# Stratovo 1.0 Beta 6

Windows graphics preparation now stages the matching LLVM 15 C++, C++ ABI and
unwind libraries into the graphics runtime. Earlier manual links are migrated
to independent copies. DXMT is load-tested before marking the runtime ready
and again before each Windows launch; a loader failure is reported before boot.

Windows display timing can be selected in Stratovo: automatic (Mac monitor),
30, 60, 90, 120, 144, 165 or 240 Hz. Shut Windows down completely before changing
the selection. The signed guest driver uses the advertised preferred timing
for all resolutions; this is not a list of simultaneous modes in Windows and
does not cap game FPS. Games retain their own FPS settings. Higher rates do
not guarantee corresponding game performance or physical monitor refresh.

The native startup view replaces a positively identified firmware logo with
an opaque black backdrop and a clean Windows-style mark. It covers firmware
boot messages, source-logo edges and the transient inactive-display placeholder
until the first completed Metal frame. Esc exposes the actual firmware UI;
the cover also expires after 30 seconds so boot failures remain visible.
Firmware, keys and guest disks are not modified. The native player uses the
Stratovo icon and a shorter window title.

Existing graphics installations require one player update. ANGLE and LLVM
builds are reused; only QEMU is rebuilt. Guest drivers do not need reinstalling
when the 3D controller is already active. The default timing remains automatic.

Master Duel at 1920 × 1080 was reported stable on the user's previous runtime.
The new startup transition and timing choices still require live testing on
that Mac. Automated checks do not replace a Windows game test.

Cleanup retains Beta 5 as a known working fallback and still requires an
explicit `BETA6 GETESTET` confirmation. Old packages go to Trash, never directly
to permanent deletion.

Developed by **PwnedG0blin**.
