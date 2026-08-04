// S6 regression (#31): Windows claim-interface failure copy must be honest.
// The code reliably distinguishes LIBUSB_ERROR_ACCESS (interface occupied /
// wrong Zadig target — the #31 case) from other libusb errors, so the
// access path must keep the actionable guidance and the fallback must stay
// the plain driver-install prompt. Locks the existing distinction so future
// edits cannot collapse both paths into a misleading single message.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const windows = "native/windows/Services/PtpCamera.cs";

test("Windows claim failure distinguishes LIBUSB_ERROR_ACCESS from other errors", async () => {
  const source = await readFile(windows, "utf8");
  assert.match(
    source,
    /var guidance = status == LibUsbNative\.ErrorAccess\s*\?[\s\S]{0,500}: "。请安装 WinUSB\/libusbK 驱动。";/,
    "access errors and generic errors must map to different guidance",
  );
});

test("Windows access-error guidance is actionable and honest about occupation", async () => {
  const source = await readFile(windows, "utf8");
  assert.match(source, /关闭 NX Tether、Camera Control Pro/, "must suggest closing occupying apps");
  assert.match(
    source,
    /在 Zadig 中选择正确的 PTP\/Still Image 接口[\s\S]{0,150}而非整个设备/,
    "must explain the correct Zadig target",
  );
  assert.match(
    source,
    /未被 Windows 内置驱动重新抢占/,
    "must warn that the built-in driver can reclaim the interface",
  );
  assert.match(source, /errorName/, "the libusb error name must be surfaced");
});

test("Windows non-access errors keep the plain driver-install prompt", async () => {
  const source = await readFile(windows, "utf8");
  assert.match(source, /请安装 WinUSB\/libusbK 驱动/, "driver-missing prompt must remain for generic errors");
});
