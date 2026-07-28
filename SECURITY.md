# Security policy

## Supported versions

Only the latest tagged release receives security fixes.

## Reporting

Please use GitHub's private security-advisory feature instead of a public issue
for vulnerabilities that could expose local photos, camera identifiers or USB
device access.

Nikon Link keeps its photo library on the local device. It does not implement
cloud upload or analytics. USB access is requested only after the user chooses
the native Nikon camera connection. The FTP wireless inbox listens only while
the user enables it and should be used on a trusted local network; stop the
receiver after camera uploads finish. On iOS/iPadOS the receiver is stopped
automatically when Nikon Link leaves the foreground.
