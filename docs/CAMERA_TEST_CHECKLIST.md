# Nikon camera hardware acceptance checklist

Record the camera firmware, lens, USB cable and host OS before testing.

- [ ] Z8 (`04b0:0451`) is identified by its correct model name.
- [ ] Z f (`04b0:0453`) is identified by its correct model name.
- [ ] Z6III (`04b0:0454`) is identified by its correct model name.
- [ ] Z5II (`04b0:0456`) is identified by its correct model name.
- [ ] Other Nikon USB models are rejected with their actual Product ID.
- [ ] Android displays a USB permission prompt once and reconnects after relaunch.
- [ ] Live view starts, refreshes continuously and stops when disabled.
- [ ] One shutter press creates exactly one file in the local library.
- [ ] Captured JPEG opens at full resolution and has a valid EXIF timestamp.
- [ ] Shutter speed, aperture, ISO and exposure compensation change on the body.
- [ ] P, M, A and S modes change on the body.
- [ ] B mode opens and closes the shutter after the selected duration.
- [ ] White balance, AF mode and exposure mode report unsupported values clearly.
- [ ] Disconnecting the cable disables the shutter without losing saved files.
- [ ] Reconnecting after sleep restores live view without restarting the host.
- [ ] A 50-frame session completes without a leaked USB handle or stalled queue.

## Wireless transfer

- [ ] Starting the wireless inbox shows the receiver IPv4 address and port 2121.
- [ ] Camera FTP profile logs in with `nikonlink` / `nikonlink` and PASV enabled.
- [ ] Manual JPEG upload appears in the Nikon Link library without restarting.
- [ ] NEF and HEIF uploads keep their original filename and extension.
- [ ] Auto upload receives consecutive captures without overwriting an existing file.
- [ ] Stopping the wireless inbox rejects new camera connections.

## Current build status

The 0.6.0 packages pass compilation, signature/container validation, native UI
startup checks and package scans confirming that DMG/APK contain no WebView or
web assets. A physical Z8 was not attached to the build machine, so the
checklist above remains the release-candidate gate for Z8, Z f, Z6III and Z5II.
