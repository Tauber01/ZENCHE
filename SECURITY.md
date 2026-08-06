# Security policy

## Supported versions

Only the latest tagged release receives security fixes.

## Reporting

Please use GitHub's private security-advisory feature instead of a public issue
for vulnerabilities that could expose local photos, camera identifiers or USB
device access.

帧澈 ZENCHE keeps its photo library on the local device. It does not implement
automatic cloud upload or analytics. The GitHub Issue action sends only the
diagnostic text visible in the prefilled form, and only after the user reviews
and submits it on GitHub; photos and complete log archives are not attached.
The only network heartbeat is an anonymous, optional update check: each app
start that has automatic update checking enabled sends the update server a
random per-install ID (stored only on the device, independent of activation
and device codes) which the server hashes to a 12-character fingerprint before
storing, alongside the platform and version, purely to count installs and
daily/weekly active users. The install ID never leaves the device as a raw
identifier, can be disabled by turning off automatic update checking, and is
never linked to photos, logs, activation codes, or camera identifiers.
USB access is requested only after the user chooses
the native Nikon camera connection. The FTP wireless inbox listens only while
the user enables it and should be used on a trusted local network; stop the
receiver after camera uploads finish. On iOS/iPadOS the receiver is stopped
automatically when 帧澈 ZENCHE leaves the foreground. Windows stops the receiver
when the application closes, and HarmonyOS stops it when the main page is
destroyed. Windows and HarmonyOS use the same fixed local FTP credentials as the
other native clients; they do not provide transport encryption and must not be
exposed to the public internet.

## AI image generation

The integrated AI features send the user's prompt text and, in AI photo-editing
mode, a base-64 encoded copy of the selected photo to a third-party image API
(grsai.dakka.com.cn). No other user data is transmitted. Only the image the
user explicitly chooses to edit is sent. AI-generated results are saved locally
in the ZENCHE library and are never uploaded automatically.
