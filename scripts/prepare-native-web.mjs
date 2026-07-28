#!/usr/bin/env node

import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const scriptRoot = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptRoot, "..");
const targetRoot = path.resolve(process.argv[2] || "");

if (!process.argv[2]) {
  throw new Error("缺少原生 Web 资源输出目录。");
}

await mkdir(targetRoot, { recursive: true });

for (const asset of ["tokens.css", "styles.css", "manifest.webmanifest", "sw.js"]) {
  await cp(path.join(projectRoot, asset), path.join(targetRoot, asset));
}
await cp(path.join(projectRoot, "icons"), path.join(targetRoot, "icons"), {
  recursive: true,
});

const [indexSource, bridgeSource, storageSource, cameraSource, appSource] =
  await Promise.all(
    ["index.html", "native-bridge.js", "storage-service.js", "camera-service.js", "app.js"].map(
      (file) => readFile(path.join(projectRoot, file), "utf8"),
    ),
  );

const moduleScripts =
  '    <script src="./native-bridge.js"></script>\n' +
  '    <script type="module" src="./app.js"></script>';
if (!indexSource.includes(moduleScripts)) {
  throw new Error("index.html 的脚本入口与原生打包器预期不一致。");
}

const nativeIndex = indexSource.replace(
  moduleScripts,
  '    <script src="./app.bundle.js"></script>',
);
const storageBody = storageSource.replace(/^export\s+/gm, "");
const cameraBody = cameraSource.replace(/^export\s+/gm, "");
const appBody = appSource.replace(/^import\s+.+?;\s*$/gm, "");
const bundle = `${bridgeSource}

(async () => {
${storageBody}

${cameraBody}

${appBody}
})().catch((error) => {
  document.documentElement.removeAttribute("inert");
  document.body?.removeAttribute("inert");
  document.querySelector("#appShell")?.removeAttribute("inert");
  const notice = document.querySelector("#runtimeNotice");
  const message = document.querySelector("#runtimeNoticeText");
  if (notice && message) {
    notice.hidden = false;
    message.textContent = "应用启动失败：" + (error?.message || String(error));
  }
  console.error("Nikon Link startup failed", error);
});
`;

await Promise.all([
  writeFile(path.join(targetRoot, "index.html"), nativeIndex),
  writeFile(path.join(targetRoot, "app.bundle.js"), bundle),
]);
