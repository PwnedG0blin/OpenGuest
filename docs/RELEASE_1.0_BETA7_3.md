# Stratovo 1.0 Beta 7.3 · Direct Android output for games

The public repository is now **PwnedG0blin/Stratovo**. This version retains the
Beta 7.2 update migration; older public apps need a manual update after the rename.

Build **1028** adds an optional **Direkt · Spiele (Mac-GPU)** output mode.
Choose it under Android → Android-Bildausgabe before starting Android.
The emulator opens its own window with `-gpu host`; Stratovo does not start
scrcpy, H.264 encoding/decoding or the integrated Android player in this mode.
The streaming module is not required for a direct launch.

This requests the host GPU. It does not guarantee a specific Metal backend:
the emulator translates Android graphics APIs and the actual renderer is
reported in diagnostics. Direct mode applies to the whole Android session,
not automatically to selected game packages. Closing the native emulator
window can shut Android down. Use the window button or Dock to activate it.

Volume controls remain available in Stratovo’s Android workspace, independently
of streaming. Resolution, APK installation and guest shutdown remain managed by
Stratovo. The integrated H.264 player stays the default and can be selected
again after shutting Android down. H.265 is not included in this release.
Windows retains its existing direct Cocoa/Metal output. Private features and
firmware are preserved. Guest disks and saved data are unchanged.

## Compare on the user's Mac

1. Keep the same Android device, CPU/RAM, resolution, refresh target, Vulkan
   setting and game graphics options. Select host GPU for the integrated player
   as well, so the presentation path is the only variable. Use a repeatable scene after warm-up.
2. Compare the integrated player at full resolution/32 Mbit/s with direct
   output, restarting Android between modes. Keep the game visible.
3. Record in-game FPS (if available), visible artifacts, input response,
   Mac CPU/GPU load and memory pressure. Stream/decoder FPS are not game FPS;
   direct mode deliberately shows no synthetic stream or game-FPS counter.
4. If the renderer reports software graphics, investigate that before judging
   the host-GPU path. A GPU request alone does not prove hardware acceleration.

CI validates launch arguments, mode persistence, private regressions, app build,
window layout and packaging. It cannot benchmark an accelerated Android game.
