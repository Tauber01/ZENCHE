import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

const expected = [
  ["Nikon Z7", 0x0442, 64, 25600],
  ["Nikon Z6", 0x0443, 100, 51200],
  ["Nikon Z50", 0x0444, 100, 51200],
  ["Nikon D780", 0x0446, 100, 51200],
  ["Nikon D6", 0x0447, 100, 102400],
  ["Nikon Z5", 0x0448, 100, 51200],
  ["Nikon Z7II", 0x044b, 64, 25600],
  ["Nikon Z6II", 0x044c, 100, 51200],
  ["Nikon Z fc", 0x044f, 100, 51200],
  ["Nikon Z9", 0x0450, 64, 25600],
  ["Nikon Z8", 0x0451, 64, 25600],
  ["Nikon Z30", 0x0452, 100, 51200],
  ["Nikon Z f", 0x0453, 100, 64000],
  ["Nikon Z6III", 0x0454, 100, 64000],
  ["Nikon Z50II", 0x0455, 100, 51200],
  ["Nikon Z5II", 0x0456, 100, 64000],
  ["Nikon ZR", 0x0457, 100, 51200],
];

const read = async (path) => readFile(new URL(path, root), "utf8");

const profilesFrom = (source, pattern) =>
  [...source.matchAll(pattern)].map((match) => [
    match[1],
    Number.parseInt(match[2], 16),
    Number.parseInt(match[3], 10),
    Number.parseInt(match[4], 10),
  ]);

test("native registries expose the same 17 camera profiles", async () => {
  const [android, harmony, macos, windows] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  assert.deepEqual(
    profilesFrom(
      android,
      /new CameraProfile\("([^"]+)", 0x([0-9a-f]+), (\d+), (\d+)\)/g,
    ),
    expected,
  );
  assert.deepEqual(
    profilesFrom(
      harmony,
      /new CameraProfile\('([^']+)', 0x([0-9a-f]+), (\d+), (\d+)\)/g,
    ),
    expected,
  );
  assert.deepEqual(
    profilesFrom(
      macos,
      /SupportedCamera\(\s*name: "([^"]+)",\s*productID: 0x([0-9a-f]+),[\s\S]*?minimumISO: (\d+),\s*maximumISO: (\d+)\s*\)/g,
    ),
    expected,
  );
  assert.deepEqual(
    profilesFrom(
      windows,
      /new\("([^"]+)", 0x([0-9a-f]+), (\d+), (\d+)\)/g,
    ),
    expected,
  );
});

test("Android USB attachment filter includes every supported Product ID", async () => {
  const filter = await read("native/android/app/src/main/res/xml/device_filter.xml");
  const productIds = [...filter.matchAll(/product-id="(\d+)"/g)]
    .map((match) => Number.parseInt(match[1], 10))
    .sort((left, right) => left - right);
  const expectedIds = expected
    .map(([, productId]) => productId)
    .sort((left, right) => left - right);

  assert.deepEqual(productIds, expectedIds);
});

test("macOS descriptor profiles distinguish Z6/Z7 generations", async () => {
  const macos = await read("native/macos/Sources/NikonLink/main.swift");

  for (const token of [
    '"nikon z6"',
    '"nikon z6 2"',
    '"nikon z6 iii"',
    '"nikon z7"',
    '"nikon z7 2"',
  ]) {
    assert.ok(macos.includes(token), `missing descriptor token ${token}`);
  }
  assert.match(macos, /\.max \{ \$0\.length < \$1\.length \}/);
});

test("Android descriptor fallback normalizes Nikon generation suffixes", async () => {
  const android = await read(
    "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java",
  );

  assert.match(android, /\.replace\("iii", "3"\)\s*\.replace\("ii", "2"\)/);
  assert.match(android, /candidateAlias\.length\(\) > bestMatchLength/);
});
