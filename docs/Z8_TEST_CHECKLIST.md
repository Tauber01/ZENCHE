# Nikon Z8 hardware acceptance checklist

Record the camera firmware, lens, USB cable and host OS before testing.

- [ ] The connection screen rejects non-Z8 Nikon models.
- [ ] Android displays a USB permission prompt once and reconnects after relaunch.
- [ ] Live view starts, refreshes continuously and stops when disabled.
- [ ] One shutter press creates exactly one file in the local library.
- [ ] Captured JPEG opens at full resolution and has a valid EXIF timestamp.
- [ ] Shutter speed, aperture, ISO and exposure compensation change on the body.
- [ ] White balance, AF mode and exposure mode report unsupported values clearly.
- [ ] Disconnecting the cable disables the shutter without losing saved files.
- [ ] Reconnecting after sleep restores live view without restarting the host.
- [ ] A 50-frame session completes without a leaked USB handle or stalled queue.

## Current build status

The 0.4.0 packages pass compilation, signature/container validation, native UI
startup checks and package scans confirming that DMG/APK contain no WebView or
web assets. A physical Z8 was not attached to the build machine, so the
checklist above remains the release-candidate gate.
