import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

const readMobile = () =>
  Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
  ]);

test("all-files main view lists the full library including categorized items", async () => {
  const [ios, android, harmony] = await readMobile();

  // iOS：visibleAllFiles 基于 model.library.items 全集，不按分支指派过滤
  assert.match(ios, /private var visibleAllFiles: \[LibraryItem\]/);
  assert.match(ios, /var result = model\.library\.items/);
  assert.doesNotMatch(ios, /visibleAllFiles[\s\S]{0,400}unclassifiedItems/);

  // Android：buildAllFilesView 接收完整 files 列表并逐一遍历（不论是否已归类）
  assert.match(android, /buildAllFilesView\(files\)/);
  assert.match(android, /for \(File file : files\)/);

  // Harmony：allFilesFiltered 基于 this.photos 全集
  assert.match(harmony, /private allFilesFiltered\(\)/);
  assert.match(harmony, /this\.photos\.filter/);
});

test("mobile all-files view supports name search, type filter, and sort", async () => {
  const [ios, android, harmony] = await readMobile();

  // iOS：搜索 + 全部/照片/视频筛选 + 最近/名称排序
  assert.match(ios, /TextField\("搜索文件名"/);
  assert.match(ios, /private enum LibraryFileFilter/);
  assert.match(ios, /case all = "全部"/);
  assert.match(ios, /case photos = "照片"/);
  assert.match(ios, /case videos = "视频"/);
  assert.match(ios, /private enum LibraryFileSort/);
  assert.match(ios, /case recent = "最近"/);
  assert.match(ios, /case name = "名称"/);

  // Android：搜索/筛选/排序状态字段 + 三档筛选与两档排序按钮
  assert.match(android, /librarySearchQuery/);
  assert.match(android, /libraryTypeFilter/);
  assert.match(android, /librarySortByName/);
  assert.match(android, /\{"全部", "照片", "视频"\}/);
  assert.match(android, /nativeButton\("最近", false\)/);
  assert.match(android, /nativeButton\("名称", false\)/);

  // Harmony：搜索/筛选/排序状态 + 全部/照片/视频与最近/名称按钮
  assert.match(harmony, /librarySearchQuery: string = ''/);
  assert.match(harmony, /libraryTypeFilter: string = 'all'/);
  assert.match(harmony, /librarySortOrder: string = 'recent'/);
  assert.match(harmony, /this\.tr\('全部'\)/);
  assert.match(harmony, /this\.tr\('照片'\)/);
  assert.match(harmony, /this\.tr\('视频'\)/);
  assert.match(harmony, /this\.tr\('最近'\)/);
  assert.match(harmony, /this\.tr\('名称'\)/);
});

test("project categories and more tools are collapsed progressive disclosure", async () => {
  const [ios, android, harmony] = await readMobile();

  assert.match(ios, /@State private var projectCategoriesExpanded = false/);
  assert.match(ios, /@State private var moreToolsExpanded = false/);
  assert.match(ios, /DisclosureGroup\(isExpanded: \$projectCategoriesExpanded\)/);
  assert.match(ios, /Label\("项目分类", systemImage: "folder"\)/);
  assert.match(ios, /Label\("更多工具", systemImage: "wrench\.and\.screwdriver"\)/);

  assert.match(
    android,
    /collapsibleGroup\(\s*"project-categories",[\s\S]{0,200}?false\)\)/
  );
  assert.match(
    android,
    /collapsibleGroup\(\s*"more-tools",[\s\S]{0,200}?false\)\)/
  );

  assert.match(harmony, /projectCategoriesExpanded: boolean = false/);
  assert.match(harmony, /moreToolsExpanded: boolean = false/);
  assert.match(harmony, /项目分类/);
  assert.match(harmony, /更多工具/);
});

test("legacy branch data stays compatible: keys unchanged, unclassified kept", async () => {
  const [ios, android, harmony] = await readMobile();

  // 持久化键与基线一致，未分类概念保留
  assert.match(ios, /UserDefaults/);
  assert.match(ios, /zenche\.library\.file-branch-assignments/);
  assert.match(ios, /未分类/);

  assert.match(android, /LIBRARY_BRANCHES_KEY = "libraryUserBranches"/);
  assert.match(android, /LIBRARY_FILE_ASSIGNMENTS_KEY/);
  assert.match(android, /未分类/);

  assert.match(harmony, /LIBRARY_BRANCHES_KEY: string = 'libraryUserBranches'/);
  assert.match(harmony, /LIBRARY_FILE_ASSIGNMENTS_KEY/);
  assert.match(harmony, /未分类/);
});

test("no new physical file operations; deletes clean only branch assignment", async () => {
  const [ios, android, harmony] = await readMobile();

  // 删除仅走既有本地删除 + 分支指派清理，且均有确认
  assert.match(ios, /func deleteLibraryFile/);
  assert.match(ios, /branchStore\.assign\(item\.id, to: nil\)/);
  assert.match(ios, /model\.library\.deleteSelected\(\)/);
  assert.match(ios, /confirmationDialog\(\s*"删除文件？"/);

  assert.match(android, /private void confirmDeleteLibraryFile\(File file\)/);
  assert.match(android, /new AlertDialog\.Builder/);
  assert.match(android, /libraryFileAssignments\.remove\(file\.getAbsolutePath\(\)\)/);

  assert.match(harmony, /private async confirmDeletePhoto\(item: PhotoItem\)/);
  assert.match(harmony, /promptAction\.showDialog/);
  assert.match(harmony, /assignment\.path !== item\.path/);

  // 物理 rename/copy/move 数量不得超出基线（d368b96）：
  // Android 仅 1 处（legacy 目录迁移），Harmony 仅 3 处（无线收件箱落盘），
  // iOS RootView 为 0。
  assert.equal(
    (android.match(/renameTo|moveItem|copyItem/g) ?? []).length,
    1
  );
  assert.equal(
    (harmony.match(/fs\.(?:rename|moveFile|copyFile)(?:Sync)?/g) ?? []).length,
    3
  );
  assert.doesNotMatch(ios, /renameTo|moveItem|copyItem/);
});

test("library sections keep source labels and empty-state guidance", async () => {
  const [ios, android, harmony] = await readMobile();

  for (const source of [ios, android, harmony]) {
    assert.match(source, /来源：相机/);
    assert.match(source, /来源：系统相册/);
    assert.match(source, /来源：无线传输/);
    assert.match(source, /拍摄新照片、从相机下载，或从系统相册导入。/);
  }
});

test("new navigation and library strings exist in zh/en/ja runtime tables", async () => {
  const [iosEn, iosJa, iosZh, androidLoc, harmonyLoc] = await Promise.all([
    read("native/ios/NikonLink/en.lproj/Localizable.strings"),
    read("native/ios/NikonLink/ja.lproj/Localizable.strings"),
    read("native/ios/NikonLink/zh-Hans.lproj/Localizable.strings"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/Localization.java"),
    read("native/harmony/entry/src/main/ets/localization/Localization.ets"),
  ]);

  // iOS .strings：zh 源串 → en/ja 译文
  assert.match(iosEn, /^"文件" = "Files";$/m);
  assert.match(iosEn, /^"文件库" = "Library";$/m);
  assert.match(iosEn, /^"所有文件" = "All Files";$/m);
  assert.match(iosEn, /^"项目分类" = "Project Categories";$/m);
  assert.match(iosEn, /^"更多工具" = "More Tools";$/m);
  assert.match(iosEn, /^"未分类" = "Uncategorized";$/m);
  assert.match(iosJa, /^"文件" = "ファイル";$/m);
  assert.match(iosJa, /^"所有文件" = "すべてのファイル";$/m);
  assert.match(iosJa, /^"项目分类" = "プロジェクト分類";$/m);
  assert.match(iosJa, /^"更多工具" = "その他のツール";$/m);
  assert.match(iosZh, /^"文件" = "文件";$/m);
  assert.match(iosZh, /^"文件库" = "文件库";$/m);
  assert.match(iosZh, /^"所有文件" = "所有文件";$/m);
  assert.match(iosZh, /^"项目分类" = "项目分类";$/m);
  assert.match(iosZh, /^"更多工具" = "更多工具";$/m);

  // Android Localization：add(zh, en, ja) 三语键值对
  assert.match(androidLoc, /add\("文件", "Files", "ファイル"\)/);
  assert.match(androidLoc, /add\("文件库", "Library", "ライブラリ"\)/);
  assert.match(androidLoc, /add\("所有文件", "All Files", "すべてのファイル"\)/);
  assert.match(androidLoc, /add\("项目分类", "Project Categories", "プロジェクト分類"\)/);
  assert.match(androidLoc, /add\("更多工具", "More Tools", "その他のツール"\)/);
  assert.match(androidLoc, /add\("未分类", "Unclassified", "未分類"\)/);

  // Harmony Localization：TranslationEntry(zh, en, ja)
  assert.match(harmonyLoc, /new TranslationEntry\('文件', 'Files', 'ファイル'\)/);
  assert.match(harmonyLoc, /new TranslationEntry\('文件库', 'Library', 'ライブラリ'\)/);
  assert.match(
    harmonyLoc,
    /new TranslationEntry\('所有文件', 'All Files', 'すべてのファイル'\)/
  );
  assert.match(
    harmonyLoc,
    /new TranslationEntry\('项目分类', 'Project Categories', 'プロジェクト分類'\)/
  );
  assert.match(
    harmonyLoc,
    /new TranslationEntry\('更多工具', 'More Tools', 'その他のツール'\)/
  );
  assert.match(
    harmonyLoc,
    /new TranslationEntry\('未分类', 'Unclassified', '未分類'\)/
  );
});

test("first-level navigation renamed from 分支 to 文件 on mobile", async () => {
  const [ios, android, harmony] = await readMobile();
  const iosModel = await read("native/ios/NikonLink/Models/AppModel.swift");

  assert.match(ios, /navTab\(\.library, title: "文件"\)/);
  // 宽屏 SideNavigation 走 displayTitle（rawValue 保持兼容）
  assert.match(iosModel, /case \.library: return "文件"/);
  assert.doesNotMatch(ios, /navTab\(\.library, title: "分支"\)/);

  assert.match(android, /navButton\("文件", "library"\)/);
  assert.doesNotMatch(android, /navButton\("分支", "library"\)/);

  assert.match(harmony, /this\.NavButton\('文件', 'library'\)/);
  assert.doesNotMatch(harmony, /this\.NavButton\('分支', 'library'\)/);
});
