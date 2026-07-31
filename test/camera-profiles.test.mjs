import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

const nikonProfiles = [
  ["Nikon D500", 0x043a, 100, 51200],
  ["Nikon D7500", 0x0445, 100, 51200],
  ["Nikon D850", 0x044a, 64, 25600],
  ["Nikon Z7", 0x0442, 64, 25600],
  ["Nikon Z6", 0x0443, 100, 51200],
  ["Nikon Z50", 0x0444, 100, 51200],
  ["Nikon D780", 0x0446, 100, 51200],
  ["Nikon D6", 0x0447, 100, 102400],
  ["Nikon Z5", 0x0448, 100, 51200],
  ["Nikon Z7II", 0x044b, 64, 25600],
  ["Nikon Z6II", 0x044c, 100, 51200],
  ["Nikon Z fc", 0x044f, 100, 51200],
  ["Nikon Z30", 0x0452, 100, 51200],
  ["Nikon Z9", 0x0450, 64, 25600],
  ["Nikon Z8", 0x0451, 64, 25600],
  ["Nikon Z f", 0x0453, 100, 64000],
  ["Nikon Z6III", 0x0454, 100, 64000],
  ["Nikon Z50II", 0x0455, 100, 51200],
  ["Nikon Z5II", 0x0456, 100, 64000],
  ["Nikon ZR", 0x0457, 100, 51200],
];

const sonyProfiles = [
  ["Sony A1", 0x0000, 100, 32000],
  ["Sony A7R V", 0x0000, 100, 32000],
  ["Sony A7 IV", 0x0000, 100, 51200],
  ["Sony A7S III", 0x0000, 80, 102400],
  ["Sony A7C II", 0x0000, 100, 51200],
];

const canonProfiles = [
  ["Canon EOS R5", 0x0000, 100, 51200],
  ["Canon EOS R6 Mark II", 0x0000, 100, 102400],
  ["Canon EOS R3", 0x0000, 100, 102400],
  ["Canon EOS R7", 0x0000, 100, 12800],
  ["Canon EOS R8", 0x0000, 100, 102400],
];

const allProfiles = [...nikonProfiles, ...sonyProfiles, ...canonProfiles];

const read = async (path) => readFile(new URL(path, root), "utf8");

const profilesFrom = (source, pattern) =>
  [...source.matchAll(pattern)].map((match) => [
    match[1],
    Number.parseInt(match[2], 16),
    Number.parseInt(match[3], 10),
    Number.parseInt(match[4], 10),
  ]);

test("native registries expose all Nikon camera profiles", async () => {
  const [android, harmony, macos, windows] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  const nikonPattern = /new CameraProfile\("(Nikon [^"]+)", "Nikon", 0x04b0, (0x[0-9a-f]+), (\d+), (\d+)\)/g;
  const harmonyNikon = /new CameraProfile\('(Nikon [^']+)', 'Nikon', 0x04b0, (0x[0-9a-f]+), (\d+), (\d+)\)/g;
  const macosNikon = /SupportedCamera\(\s*name: "(Nikon [^"]+)",\s*vendorName: "Nikon",\s*vendorID: 0x04b0,[\s\S]*?productID: (0x[0-9a-f]+),[\s\S]*?minimumISO: (\d+),\s*maximumISO: (\d+)\s*\)/g;
  const windowsNikon = /new\("(Nikon [^"]+)", "Nikon", 0x04b0, (0x[0-9a-f]+), (\d+), (\d+)\)/g;

  assert.deepEqual(profilesFrom(android, nikonPattern), nikonProfiles);
  assert.deepEqual(profilesFrom(harmony, harmonyNikon), nikonProfiles);
  assert.deepEqual(profilesFrom(macos, macosNikon), nikonProfiles);
  assert.deepEqual(profilesFrom(windows, windowsNikon), nikonProfiles);
});

test("native registries expose Sony α profiles", async () => {
  const [harmony, macos, windows] = await Promise.all([
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  const harmonySony = /new CameraProfile\('(Sony [^']+)', 'Sony', 0x054c, (0x[0-9a-f]+), (\d+), (\d+)\)/g;
  const macosSony = /SupportedCamera\(\s*name: "(Sony [^"]+)",\s*vendorName: "Sony",\s*vendorID: 0x054c,[\s\S]*?productID: (0x[0-9a-f]+),[\s\S]*?minimumISO: (\d+),\s*maximumISO: (\d+)\s*\)/g;
  const windowsSony = /new\("(Sony [^"]+)", "Sony", 0x054c, (0x[0-9a-f]+), (\d+), (\d+)\)/g;

  assert.deepEqual(profilesFrom(harmony, harmonySony), sonyProfiles);
  assert.deepEqual(profilesFrom(macos, macosSony), sonyProfiles);
  assert.deepEqual(profilesFrom(windows, windowsSony), sonyProfiles);
});

test("native registries expose Canon EOS R profiles", async () => {
  const [harmony, macos, windows] = await Promise.all([
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  const harmonyCanon = /new CameraProfile\('(Canon [^']+)', 'Canon', 0x04a9, (0x[0-9a-f]+), (\d+), (\d+)\)/g;
  const macosCanon = /SupportedCamera\(\s*name: "(Canon [^"]+)",\s*vendorName: "Canon",\s*vendorID: 0x04a9,[\s\S]*?productID: (0x[0-9a-f]+),[\s\S]*?minimumISO: (\d+),\s*maximumISO: (\d+)\s*\)/g;
  const windowsCanon = /new\("(Canon [^"]+)", "Canon", 0x04a9, (0x[0-9a-f]+), (\d+), (\d+)\)/g;

  assert.deepEqual(profilesFrom(harmony, harmonyCanon), canonProfiles);
  assert.deepEqual(profilesFrom(macos, macosCanon), canonProfiles);
  assert.deepEqual(profilesFrom(windows, windowsCanon), canonProfiles);
});

test("all platforms expose Sony and Canon vendor IDs in their supported sets", async () => {
  const [harmonyCam, windowsCam, androidCam] = await Promise.all([
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/windows/Models/CameraProfile.cs"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
  ]);

  assert.ok(harmonyCam.includes("0x054c"), "HarmonyOS missing Sony vendor ID");
  assert.ok(harmonyCam.includes("0x04a9"), "HarmonyOS missing Canon vendor ID");
  assert.ok(windowsCam.includes("0x054c"), "Windows missing Sony vendor ID");
  assert.ok(windowsCam.includes("0x04a9"), "Windows missing Canon vendor ID");
  assert.ok(androidCam.includes("0x054c"), "Android missing Sony vendor ID");
  assert.ok(androidCam.includes("0x04a9"), "Android missing Canon vendor ID");
});

test("Android USB attachment filter includes Nikon, Sony, and Canon fallbacks", async () => {
  const filter = await read("native/android/app/src/main/res/xml/device_filter.xml");
  const vendorIds = [...filter.matchAll(/vendor-id="(\d+)"/g)]
    .map((match) => Number.parseInt(match[1], 10))
    .sort((left, right) => left - right);
  const expectedIds = [1193, 1200, 1356];
  for (const id of expectedIds) {
    assert.ok(vendorIds.includes(id), `device_filter.xml missing vendor-id="${id}"`);
  }
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

test("macOS descriptor profiles include Sony and Canon detection tokens", async () => {
  const macos = await read("native/macos/Sources/NikonLink/main.swift");

  for (const token of [
    '"sony a7 iv"',
    '"sony ilce-7m4"',
    '"canon eos r5"',
    '"eos r5"',
  ]) {
    assert.ok(macos.includes(token), `missing detection token ${token}`);
  }
});

test("Android descriptor fallback normalizes brand-specific generation suffixes", async () => {
  const android = await read(
    "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java",
  );

  assert.match(android, /\.replace\("iii", "3"\)\s*\.replace\("ii", "2"\)/);
  assert.match(android, /candidateAlias\.length\(\) > bestMatchLength/);
  assert.match(android, /candidate\.vendorName\.toLowerCase/);
});
