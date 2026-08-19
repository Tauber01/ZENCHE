import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = new URL("../", import.meta.url);

function available(command, args = ["--version"]) {
  return spawnSync(command, args, { stdio: "ignore" }).status === 0;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: new URL(".", root),
    encoding: "utf8",
    timeout: 120_000,
    ...options,
  });
  assert.equal(
    result.status,
    0,
    `${command} failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  return result.stdout;
}

const hasSwift = process.platform === "darwin" &&
  available("xcrun", ["--find", "swiftc"]);
const dotnetSdks = spawnSync("dotnet", ["--list-sdks"], {
  encoding: "utf8",
});
const hasDotnet8 = dotnetSdks.status === 0 &&
  dotnetSdks.stdout.split(/\r?\n/).some((line) => /^8\./.test(line));

test("macOS real filesystem rollback restores paired XMP after manifest failure", {
  skip: !hasSwift,
}, async () => {
  const temporary = await mkdtemp(join(tmpdir(), "zenche-macos-rollback-test-"));
  try {
    const executable = join(temporary, "rollback-harness");
    run("xcrun", [
      "swiftc",
      "-swift-version", "5",
      "-parse-as-library",
      "-module-cache-path", join(temporary, "module-cache"),
      "-o", executable,
      new URL(
        "native/macos/Sources/NikonLink/CaptureWorkflow.swift",
        root
      ).pathname,
      new URL("test/fixtures/macos-import-rollback.swift", root).pathname,
    ]);
    const output = run(executable, []);
    assert.match(output, /macOS import rollback behavior: PASS/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("Windows real filesystem rollback restores paired XMP after manifest failure", {
  skip: !hasDotnet8,
}, async () => {
  const temporary = await mkdtemp(join(tmpdir(), "zenche-windows-rollback-test-"));
  try {
    const project = new URL(
      "test/fixtures/windows-import-rollback/ImportRollbackHarness.csproj",
      root
    ).pathname;
    const common = [
      `-p:BaseIntermediateOutputPath=${join(temporary, "obj")}/`,
      `-p:BaseOutputPath=${join(temporary, "bin")}/`,
      `-p:RestorePackagesPath=${join(temporary, "packages")}`,
      "-p:NuGetAudit=false",
    ];
    const env = {
      ...process.env,
      DOTNET_CLI_HOME: temporary,
      DOTNET_NOLOGO: "1",
      DOTNET_SKIP_FIRST_TIME_EXPERIENCE: "1",
    };
    run("dotnet", [
      "restore", project,
      "--ignore-failed-sources",
      ...common,
    ], { env });
    const output = run("dotnet", [
      "run", "--project", project,
      "--no-restore",
      ...common,
    ], { env });
    assert.match(output, /Windows import rollback behavior: PASS/);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
