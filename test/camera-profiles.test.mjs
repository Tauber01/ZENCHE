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
  ["Sony A1 II", 0x0000, 100, 32000],
  ["Sony A9 III", 0x0000, 100, 51200],
  ["Sony A7R V", 0x0000, 100, 32000],
  ["Sony A7 IV", 0x0000, 100, 51200],
  ["Sony A7S III", 0x0000, 80, 102400],
  ["Sony A7C II", 0x0000, 100, 51200],
  ["Sony A7C R", 0x0000, 100, 32000],
  ["Sony ZV-E1", 0x0000, 80, 102400],
  ["Sony A6100", 0x0000, 100, 32000],
  ["Sony A6400", 0x0000, 100, 32000],
  ["Sony A6600", 0x0000, 100, 32000],
  ["Sony A6700", 0x0000, 100, 32000],
  ["Sony FX30", 0x0000, 100, 32000],
  ["Sony ZV-E10", 0x0000, 100, 32000],
  ["Sony ZV-E10 II", 0x0000, 100, 32000],
];

const canonProfiles = [
  ["Canon EOS R1", 0x0000, 100, 102400],
  ["Canon EOS R3", 0x0000, 100, 102400],
  ["Canon EOS R5", 0x0000, 100, 51200],
  ["Canon EOS R5 Mark II", 0x0000, 100, 51200],
  ["Canon EOS R6 Mark II", 0x0000, 100, 102400],
  ["Canon EOS R7", 0x0000, 100, 12800],
  ["Canon EOS R8", 0x0000, 100, 102400],
  ["Canon EOS R10", 0x0000, 100, 12800],
  ["Canon EOS R50", 0x0000, 100, 12800],
  ["Canon EOS R100", 0x0000, 100, 12800],
  ["Canon EOS R6 Mark III", 0x0000, 100, 64000],
  ["Canon EOS R6", 0x0000, 100, 102400],
  ["Canon EOS R5 C", 0x0000, 100, 51200],
  ["Canon EOS R50 V", 0x0000, 100, 32000],
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
  const [android, harmony, macos, windows] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  const androidSony = /new CameraProfile\("(Sony [^"]+)", "Sony", 0x054c, (0x[0-9a-f]+), (\d+), (\d+)\)/g;
  const harmonySony = /new CameraProfile\('(Sony [^']+)', 'Sony', 0x054c, (0x[0-9a-f]+), (\d+), (\d+)\)/g;
  const macosSony = /SupportedCamera\(\s*name: "(Sony [^"]+)",\s*vendorName: "Sony",\s*vendorID: 0x054c,[\s\S]*?productID: (0x[0-9a-f]+),[\s\S]*?minimumISO: (\d+),\s*maximumISO: (\d+)\s*\)/g;
  const windowsSony = /new\("(Sony [^"]+)", "Sony", 0x054c, (0x[0-9a-f]+), (\d+), (\d+)\)/g;

  assert.deepEqual(profilesFrom(android, androidSony), sonyProfiles);
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

test("zero Product IDs act as vendor wildcards for Sony and Canon USB devices", async () => {
  const [android, harmony, macos, windows] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  assert.match(
    android,
    /candidate\.productId != 0[\s\S]*candidate\.productId == productId/,
    "Android must prefer exact Product IDs",
  );
  assert.match(
    android,
    /vendorFallbackProfile\(device\.getVendorId\(\)\)/,
    "Android must fall back to a generic vendor profile",
  );
  assert.match(
    harmony,
    /profile\.productId !== 0[\s\S]*profile\.productId === productId/,
    "HarmonyOS must prefer exact Product IDs",
  );
  assert.match(
    harmony,
    /Sony ' \+ 'α USB\/PTP[\s\S]*Canon ' \+ 'EOS USB\/PTP/,
    "HarmonyOS must fall back to generic vendor profiles",
  );
  assert.match(
    macos,
    /\$0\.productID != 0[\s\S]*\$0\.productID == productID/,
    "macOS must prefer exact Product IDs",
  );
  assert.match(
    macos,
    /matchingVendor\(vendorID: Int\)[\s\S]*Sony " \+ "α USB\/PTP[\s\S]*Canon " \+ "EOS USB\/PTP/,
    "macOS must fall back to generic vendor profiles",
  );
  assert.match(
    windows,
    /camera\.ProductId != 0[\s\S]*camera\.ProductId == productId/,
    "Windows must prefer exact Product IDs",
  );
  assert.match(
    windows,
    /Sony " \+ "α USB\/PTP[\s\S]*Canon " \+ "EOS USB\/PTP/,
    "Windows must fall back to generic vendor profiles",
  );
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
  // Input and candidate share one normalization rule: lowercase happens
  // BEFORE the vendor prefix is removed, so "SONY ILCE-…" descriptors and
  // "Sony A6100" registry names lose their vendor identically.
  assert.match(android, /private static String normalizeModelName/);
  assert.match(android, /String lower = value\.toLowerCase\(Locale\.ROOT\)/);
  assert.match(android, /lower\.replace\(vendorName\.toLowerCase\(Locale\.ROOT\), ""\)/);
  assert.match(android, /normalizeModelName\(\s*descriptor, vendorNameFor\(device\.getVendorId\(\)\)\)/);
  assert.match(android, /normalizeModelName\(\s*candidate\.name, candidate\.vendorName\)/);
});

test("Android descriptor matching is executable and case-insensitive on both sides", async () => {
  const android = await read(
    "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java",
  );

  // Faithful JS mirror of PtpCamera.normalizeModelName + profileFor's
  // descriptor path, fed by the real registry parsed from source.
  const profiles = [...android.matchAll(
    /new CameraProfile\("([^"]+)", "([^"]+)", 0x([0-9a-f]+), 0x([0-9a-f]+), (\d+), (\d+)\)/g,
  )].map((m) => ({
    name: m[1],
    vendorName: m[2],
    vendorId: Number.parseInt(m[3], 16),
    productId: Number.parseInt(m[4], 16),
  }));

  const normalize = (value, vendorName) => {
    const lower = value.toLowerCase();
    const withoutVendor =
      vendorName === null || vendorName === ""
        ? lower
        : lower.replace(vendorName.toLowerCase(), "");
    return withoutVendor
      .replace(/ilce/g, "a")
      .replace(/ilme/g, "")
      .replace(/_/g, "")
      .replace(/-/g, "")
      .replace(/ /g, "");
  };

  const vendorNameFor = (vendorId) =>
    profiles.find((p) => p.vendorId === vendorId)?.vendorName ?? null;

  const matchDescriptor = (descriptor, vendorId) => {
    const normalized = normalize(descriptor, vendorNameFor(vendorId));
    const generationAlias = normalized
      .replace(/iii/g, "3")
      .replace(/ii/g, "2")
      .replace(/m3/g, "3")
      .replace(/m2/g, "2");
    let best = null;
    let bestLength = 0;
    for (const candidate of profiles) {
      const candidateName = normalize(candidate.name, candidate.vendorName);
      const candidateAlias = candidateName.replace(/iii/g, "3").replace(/ii/g, "2");
      if (
        (normalized.includes(candidateName) ||
          generationAlias.includes(candidateAlias)) &&
        candidateAlias.length > bestLength
      ) {
        best = candidate.name;
        bestLength = candidateAlias.length;
      }
    }
    return best;
  };

  // The exact regression GPT5.6 flagged: vendor removal must be
  // case-insensitive, so an uppercase descriptor still matches.
  assert.equal(
    normalize("SONY A6100", "Sony"),
    normalize("Sony A6100", "Sony"),
    "input and candidate must normalize identically",
  );
  assert.equal(normalize("Sony A6100", "Sony"), "a6100");
  assert.equal(normalize("Sony ZV-E10 II", "Sony"), "zve10ii");

  // Descriptor -> profile resolution on real registry data.
  assert.equal(matchDescriptor("Sony ZV-E10", 0x054c), "Sony ZV-E10");
  assert.equal(matchDescriptor("SONY ZV-E10", 0x054c), "Sony ZV-E10");
  assert.equal(matchDescriptor("Sony ZV-E10 II", 0x054c), "Sony ZV-E10 II");
  // ILCE/ZV-E10M2 must bind to ZV-E10 II, never the base ZV-E10.
  assert.equal(matchDescriptor("SONY ILCE-ZVE10M2", 0x054c), "Sony ZV-E10 II");
  assert.equal(matchDescriptor("Sony ZV-E10M2", 0x054c), "Sony ZV-E10 II");
  assert.notEqual(matchDescriptor("SONY ILCE-ZVE10M2", 0x054c), "Sony ZV-E10");
  // ILCE-1M2 / A1M2 must bind to A1 II, never the base A1.
  assert.equal(matchDescriptor("Sony A1", 0x054c), "Sony A1");
  assert.equal(matchDescriptor("Sony A1 II", 0x054c), "Sony A1 II");
  assert.equal(matchDescriptor("SONY ILCE-1M2", 0x054c), "Sony A1 II");
  assert.equal(matchDescriptor("Sony A1M2", 0x054c), "Sony A1 II");
  assert.notEqual(matchDescriptor("SONY ILCE-1M2", 0x054c), "Sony A1");
  // ILCE/ILME prefixes fold onto the registry naming domain.
  assert.equal(matchDescriptor("Sony ILCE-6100", 0x054c), "Sony A6100");
  assert.equal(matchDescriptor("Sony A6100", 0x054c), "Sony A6100");
  assert.equal(matchDescriptor("Sony A6100A", 0x054c), "Sony A6100");
  assert.equal(matchDescriptor("Sony A6400A", 0x054c), "Sony A6400");
  assert.equal(matchDescriptor("Sony A6600", 0x054c), "Sony A6600");
  assert.equal(matchDescriptor("Sony ILME-FX30", 0x054c), "Sony FX30");
  assert.equal(matchDescriptor("Nikon Z9", 0x04b0), "Nikon Z9");
});

test("Windows Sony SDK model matching resolves the longest alias, never the base model", async () => {
  const camera = await read(
    "native/windows/Models/CameraProfile.cs",
  );

  assert.match(camera, /SonyModelAliases/);
  assert.match(camera, /MatchSonyModel/);
  // ZV-E10M2 must bind to ZV-E10 II, not ZV-E10.
  assert.match(camera, /\["zve10m2"\] = "Sony ZV-E10 II"/);
  assert.match(camera, /\["zve10"\] = "Sony ZV-E10"/);
  assert.match(camera, /\["zve10ii"\] = "Sony ZV-E10 II"/);
  // ILCE-1M2 / A1M2 must bind to A1 II, not A1.
  assert.match(camera, /\["a1m2"\] = "Sony A1 II"/);
  assert.match(camera, /\["a1ii"\] = "Sony A1 II"/);
  assert.match(camera, /\["a1"\] = "Sony A1"/);
  // A6100A / A6400A aliases land on the base A6100 / A6400 profiles.
  assert.match(camera, /\["a6100a"\] = "Sony A6100"/);
  assert.match(camera, /\["a6400a"\] = "Sony A6400"/);
  // Longest contained alias wins.
  assert.match(
    camera,
    /normalized\.Contains\(pair\.Key[\s\S]{0,140}?pair\.Key\.Length > bestLength/,
  );
});

test("Windows SDK matching delegates to the shared Sony alias matcher", async () => {
  const sdk = await read(
    "native/windows/Services/SonyOfficialSdkCamera.cs",
  );

  assert.match(sdk, /CameraProfile\.MatchSonyModel\(model\)/);
});

test("macOS Sony descriptor matching is executable and keeps M2/II off the base models", async () => {
  const macos = await read("native/macos/Sources/NikonLink/main.swift");

  // Faithful JS mirror of SupportedCamera.matching(detection:), fed by the
  // real detectionTokens parsed from source.
  const blocks = [...macos.matchAll(
    /SupportedCamera\(\s*name: "([^"]+)",\s*vendorName: "Sony",[\s\S]*?detectionTokens: \[([^\]]*)\],[\s\S]*?minimumISO: (\d+),\s*maximumISO: (\d+)\s*\)/g,
  )].map((m) => ({
    name: m[1],
    tokens: [...m[2].matchAll(/"([^"]+)"/g)].map((t) => t[1]),
  }));

  const matching = (detection) => {
    const normalized = detection
      .toLowerCase()
      .replace(/:/g, " ")
      .replace(/_/g, " ")
      .replace(/-/g, " ")
      .split(/\s+/)
      .filter(Boolean)
      .join(" ");
    let best = null;
    let bestLength = 0;
    for (const camera of blocks) {
      const length = camera.tokens
        .filter((token) => normalized.includes(token))
        .map((token) => token.length)
        .reduce((a, b) => Math.max(a, b), 0);
      if (length > bestLength) {
        bestLength = length;
        best = camera.name;
      }
    }
    return best;
  };

  // Realistic gphoto2 / Camera Remote SDK detection strings.
  assert.equal(matching("Sony ILCE-ZVE10"), "Sony ZV-E10");
  assert.equal(matching("Sony ILCE-ZVE10M2"), "Sony ZV-E10 II");
  assert.equal(matching("Sony ZV-E10"), "Sony ZV-E10");
  assert.equal(matching("Sony ZV-E10M2"), "Sony ZV-E10 II");
  assert.equal(matching("Sony ILCE-1M2"), "Sony A1 II");
  assert.equal(matching("Sony ILCE-6100A"), "Sony A6100");
  assert.equal(matching("Sony ILCE-6400A"), "Sony A6400");
  assert.equal(matching("Sony ILCE-6600"), "Sony A6600");

  // Longest-token rule: II must never fall back to the base model.
  const zve10 = blocks.find((b) => b.name === "Sony ZV-E10");
  const zve10II = blocks.find((b) => b.name === "Sony ZV-E10 II");
  const a1II = blocks.find((b) => b.name === "Sony A1 II");
  assert.ok(zve10 && zve10II && a1II, "expected ZV-E10, ZV-E10 II, and A1 II blocks");
  assert.ok(
    zve10.tokens.every((t) => !t.includes("m2")),
    "first-gen ZV-E10 tokens must not carry the m2 marker",
  );
  assert.ok(zve10II.tokens.includes("sony ilce zve10m2"));
  assert.ok(zve10II.tokens.includes("sony zve10m2"));
  assert.ok(a1II.tokens.includes("sony ilce 1m2"));
});

test("Windows Sony SDK matching is executable and resolves M2/II off the base models", async () => {
  const camera = await read(
    "native/windows/Models/CameraProfile.cs",
  );

  // Faithful JS mirror of CameraProfile.NormalizeSonyModel +
  // MatchSonyModel, fed by the real alias dictionary parsed from source.
  const aliases = [...camera.matchAll(
    /\["([a-z0-9]+)"\] = "([^"]+)"/g,
  )].map((m) => [m[1], m[2]]);

  const normalize = (model) =>
    model
      .replace(/ILCE-/gi, "A")
      .replace(/ILME-/gi, "")
      .toLowerCase()
      .replace(/[-_\u00a0 ]/g, "");

  const matchSonyModel = (model) => {
    const normalized = normalize(model);
    if (normalized.length === 0) return null;
    let bestName = null;
    let bestLength = -1;
    for (const [key, name] of aliases) {
      if (normalized.includes(key) && key.length > bestLength) {
        bestLength = key.length;
        bestName = name;
      }
    }
    return bestName;
  };

  assert.equal(matchSonyModel("ILCE-ZVE10M2"), "Sony ZV-E10 II");
  assert.equal(matchSonyModel("ILCE-ZVE10"), "Sony ZV-E10");
  assert.equal(matchSonyModel("ZV-E10M2"), "Sony ZV-E10 II");
  assert.equal(matchSonyModel("ZV-E10"), "Sony ZV-E10");
  assert.equal(matchSonyModel("ILCE-1M2"), "Sony A1 II");
  assert.equal(matchSonyModel("ILCE-1"), "Sony A1");
  assert.equal(matchSonyModel("ILCE-6100A"), "Sony A6100");
  assert.equal(matchSonyModel("ILCE-6400A"), "Sony A6400");
  assert.equal(matchSonyModel("ILCE-6600"), "Sony A6600");
  assert.equal(matchSonyModel("A6100A"), "Sony A6100");
  assert.equal(matchSonyModel("A6400A"), "Sony A6400");
  // The M2 alias must out-rank the bare zve10 key on the same input.
  const zve10m2 = aliases.find(([k]) => k === "zve10m2");
  const zve10 = aliases.find(([k]) => k === "zve10");
  assert.equal(zve10m2?.[1], "Sony ZV-E10 II");
  assert.equal(zve10?.[1], "Sony ZV-E10");
});

test("Android SUPPORTED_CAMERA_SUMMARY lists every registered Sony model", async () => {
  const android = await read(
    "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java",
  );

  const summary = android.match(/SUPPORTED_CAMERA_SUMMARY\s*=\s*([^;]+);/)?.[1] ?? "";
  assert.ok(summary, "expected SUPPORTED_CAMERA_SUMMARY constant");
  // The Sony block is listed as "Sony A1、A1 II、A9 III、…" — the first
  // model keeps the "Sony " prefix, the rest are bare names joined by 、.
  const sonyBlock = summary.slice(summary.indexOf("Sony A1"));
  for (const [name] of sonyProfiles) {
    const bare = name.replace("Sony ", "");
    if (name === "Sony A1") {
      assert.ok(
        sonyBlock.includes("Sony A1"),
        `${name} missing from SUPPORTED_CAMERA_SUMMARY`,
      );
    } else {
      assert.ok(
        sonyBlock.includes(bare),
        `${name} missing from SUPPORTED_CAMERA_SUMMARY`,
      );
    }
  }
});


test("all four native registries carry the new Sony APS-C entries with native ISO 100-32000", async () => {
  const [android, harmony, macos, windows] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
    read("native/harmony/entry/src/main/ets/camera/CameraProfiles.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Models/CameraProfile.cs"),
  ]);

  for (const source of [android, harmony, macos, windows]) {
    for (const model of ["Sony A6100", "Sony A6400", "Sony A6600", "Sony ZV-E10"]) {
      assert.ok(
        source.includes(model),
        `${model} missing from a native registry`,
      );
    }
  }
  // Each platform spells the native ISO range in its own syntax.
  assert.match(android, /new CameraProfile\("Sony A6100", "Sony", 0x054c, 0x0000, 100, 32000\)/);
  assert.match(harmony, /new CameraProfile\('Sony A6100', 'Sony', 0x054c, 0x0000, 100, 32000\)/);
  assert.match(macos, /name: "Sony A6100",[\s\S]*?minimumISO: 100,\s*maximumISO: 32000/);
  assert.match(windows, /new\("Sony A6100", "Sony", 0x054c, 0x0000, 100, 32000\)/);
  assert.match(macos, /name: "Sony ZV-E10",[\s\S]*?minimumISO: 100,\s*maximumISO: 32000/);
  assert.match(windows, /new\("Sony ZV-E10", "Sony", 0x054c, 0x0000, 100, 32000\)/);
});
