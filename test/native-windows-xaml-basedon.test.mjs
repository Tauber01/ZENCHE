// v1.5.9 实测修复（Tauber Windows 实测报错）：
// WPF Style.BasedOn 不是 DependencyProperty，运行时不允许 DynamicResource——
// 「不能在"Style"类型的"BasedOn"属性上设置"DynamicResourceExtension"。只能在
// DependencyObject 的 DependencyProperty 上设置"DynamicResourceExtension"」。
// 派生样式（PrimaryButton/DangerButton/NavButton/MonitorIconButton/
// EditorToolActive）的 BasedOn 必须是 StaticResource（基样式 ButtonBase/
// EditorToolButton 在同文件先定义，前向引用成立）。锁死防回归。
import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

const windowsRoot = "native/windows";

async function xamlFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) files.push(...(await xamlFiles(path)));
    else if (entry.name.endsWith(".xaml")) files.push(path);
  }
  return files;
}

test("Windows XAML: Style.BasedOn 一律 StaticResource（DynamicResource 运行时崩溃）", async () => {
  const files = await xamlFiles(windowsRoot);
  assert.ok(files.length > 0, "应扫描到 XAML 文件");
  for (const file of files) {
    const source = await readFile(file, "utf8");
    assert.ok(
      !/BasedOn="\{DynamicResource/.test(source),
      `${file} 存在 BasedOn DynamicResource（BasedOn 非 DependencyProperty，运行时必崩）`,
    );
  }
});

test("Windows XAML: Controls.xaml 派生按钮样式 BasedOn 指向已定义基样式", async () => {
  const source = await readFile(join(windowsRoot, "Themes/Controls.xaml"), "utf8");
  for (const key of ["PrimaryButton", "DangerButton", "NavButton", "MonitorIconButton"]) {
    assert.match(
      source,
      new RegExp(`x:Key="${key}" TargetType="Button" BasedOn="\\{StaticResource ButtonBase\\}"`),
      `${key} 应 BasedOn StaticResource ButtonBase`,
    );
  }
  assert.match(
    source,
    /x:Key="EditorToolActive" TargetType="Button" BasedOn="\{StaticResource EditorToolButton\}"/,
    "EditorToolActive 应 BasedOn StaticResource EditorToolButton",
  );
  // 基样式须先于派生样式定义（StaticResource 不支持前向引用）。
  assert.ok(
    source.indexOf('x:Key="ButtonBase"') < source.indexOf('x:Key="PrimaryButton"'),
    "ButtonBase 应先于派生样式定义",
  );
  assert.ok(
    source.indexOf('x:Key="EditorToolButton"') < source.indexOf('x:Key="EditorToolActive"'),
    "EditorToolButton 应先于 EditorToolActive 定义",
  );
});
