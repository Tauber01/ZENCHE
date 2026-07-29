# Security policy

## Supported versions

Only the latest tagged release receives security fixes.

## Reporting

Please use GitHub's private security-advisory feature instead of a public issue
for vulnerabilities that could expose local photos, camera identifiers or USB
device access.

Nikon Link keeps its photo library on the local device. It does not implement
automatic cloud upload or analytics. The GitHub Issue action sends only the
diagnostic text visible in the prefilled form, and only after the user reviews
and submits it on GitHub; photos and complete log archives are not attached.
USB access is requested only after the user chooses
the native Nikon camera connection. The FTP wireless inbox listens only while
the user enables it and should be used on a trusted local network; stop the
receiver after camera uploads finish. On iOS/iPadOS the receiver is stopped
automatically when Nikon Link leaves the foreground. Windows stops the receiver
when the application closes, and HarmonyOS stops it when the main page is
destroyed. Windows and HarmonyOS use the same fixed local FTP credentials as the
other native clients; they do not provide transport encryption and must not be
exposed to the public internet.
