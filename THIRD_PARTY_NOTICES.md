# Third-party notices

The macOS package bundles `gphoto2` and `libgphoto2`, distributed under their
respective GNU GPL-2.0-or-later and GNU LGPL-2.1-or-later licenses. Source,
license text and release information are available from the upstream project:

- https://github.com/gphoto/gphoto2
- https://github.com/gphoto/libgphoto2

The Windows package includes `libusb-1.0.dll`, distributed under the GNU
LGPL-2.1-or-later license. 帧澈 ZENCHE does not vendor that binary in this
repository; release builders obtain it from the official upstream release:

- https://github.com/libusb/libusb

The macOS and Windows release packages include the binary runtime components of
Sony Camera Remote SDK 2.02.00 when built from the official archives supplied
by the release builder. Those components remain subject to Sony's Camera Remote
SDK license agreement. Sony, Alpha, Cinema Line and Sony camera model names are
trademarks of Sony Group Corporation or its affiliates. 帧澈 ZENCHE is developed
and supported independently and is not endorsed by Sony.

Sony Camera Remote SDK also includes separately licensed open-source components,
including libusb and libssh2. The applicable notices and source-code offers are
described by Sony in the SDK documentation bundled with the desktop packages:

- https://support.d-imaging.sony.co.jp/app/sdk/licenseagreement/en.html
- https://libusb.info/
- https://libssh2.org/

The release packages also include Nikon's proprietary Remote SDK and Image SDK
binary runtimes when built from the official archives supplied by the release
builder. Nikon, EXPEED and Nikon camera model names are trademarks of Nikon
Corporation. 帧澈 ZENCHE is developed and supported independently and is not
endorsed by Nikon Corporation.
