# Stratovo 1.0 Beta 7.1 · Windows, sound and sharper Android video

- Midnight appearance now also covers Android/Ubuntu player windows, title bars,
  resolution and paste dialogs, help, diagnostics, storage setup and private
  update connection dialogs. Glass controls are used on macOS 26; older systems
  and accessibility settings keep the compatible solid surfaces.
- Windows continues to use its direct native Cocoa/Metal graphics window by
  default. Styling the app's controls does not enable the experimental embedded
  Windows player or add VNC frame copies to direct output.
- Android stream quality is independent of the guest performance profile.
  **Scharf · volle Auflösung** is the default and removes the former 1280-pixel
  stream limit of the Smooth profile. Its higher bitrate reduces compression
  loss, including in games. High resolution can require more encoding/GPU
  resources; this release does not promise a particular game frame rate.
- The player reports its actual received pixel dimensions, stream/decoder rate
  and active FPS limit. A quality change can be applied by reconnecting only
  the display. Android apps, accounts and saved data remain in place.
- Android media volume is queried from the guest and can be adjusted with a
  slider or muted/restored. Only media volume is changed, not Mac master volume.
- Windows/Ubuntu get USB audio output through CoreAudio and guest media-volume
  keys. Windows controls are in Stratovo's Windows workspace, alongside its
  direct graphics window. Restart a guest once to attach the audio device.

Continuing public prerelease, **build 1026**. The private beta remains separate,
with its private extensions, firmware and authenticated update channel.
Existing guest storage, disk capacity, partitions and graphics mode are retained.
No cleanup scripts are generated. Guest partition auto-resizing is not included.

Automated packaging, integration tests and static window captures do not replace
testing game image quality, sound and performance on the user's Mac.
