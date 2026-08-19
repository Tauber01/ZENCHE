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

  // Android：回收式 Adapter 的输入是 photoFiles() 全集，不按项目指派过滤。
  assert.match(android, /LibraryFileListAdapter adapter = new LibraryFileListAdapter\(files\)/);
  assert.match(android, /allFiles = new ArrayList<>\(files\)/);

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

  const androidProjectCategories = android.slice(
    android.indexOf('collapsibleGroupLocalizedLazy(\n                "project-categories"'),
    android.indexOf('collapsibleGroupLocalizedLazy(\n                "project-categories"') + 1_800
  );
  assert.match(androidProjectCategories, /false\)\);/);
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
  const iosModel = await read("native/ios/NikonLink/Models/AppModel.swift");

  // iOS 只在物理删除成功后清理归类，失败保留指派并显示消息。
  assert.match(ios, /func deleteLibraryFile/);
  assert.match(
    ios,
    /let deleted = model\.library\.deleteSelected\(locale: locale\)[\s\S]{0,220}if deleted \{[\s\S]{0,120}branchStore\.assign\(item\.id, to: nil\)/
  );
  assert.match(ios, /libraryActionMessage = model\.library\.message/);
  assert.match(
    iosModel,
    /func deleteSelected\(locale: Locale = \.current\) -> Bool/
  );
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
    assert.match(source, /去拍摄/);
  }
  assert.match(ios, /拍摄新照片，或连接相机后下载到文件库。/);
  assert.match(harmony, /拍摄新照片，或连接相机后下载到文件库。/);
  assert.match(android, /还没有文件\\n拍摄新照片、从相机下载，或从系统相册导入。/);
});

test("all-files rows expose preview and compact or accessible actions", async () => {
  const [ios, android, harmony] = await readMobile();

  // iOS 手机行只保留显式预览与单一更多菜单，其余操作收入 Menu。
  const iosRow = ios.slice(
    ios.indexOf("private func allFileRow"),
    ios.indexOf("private var moreToolsSection")
  );
  assert.match(iosRow, /LibraryFileThumbnail\(item: item\)/);
  assert.match(iosRow, /RuntimeLocalization\.format\(\s*"预览 %@"/);
  assert.match(iosRow, /RuntimeLocalization\.format\(\s*"更多操作 %@"/);
  assert.match(iosRow, /Menu \{/);
  assert.match(iosRow, /Label\("导出副本"/);
  assert.match(iosRow, /ShareLink/);
  assert.match(iosRow, /Label\("移动到项目"/);
  assert.match(iosRow, /ellipsis\.circle/);
  assert.equal((iosRow.match(/frame\(width: 44, height: 44\)/g) ?? []).length, 2);

  // Android 行和显式预览按钮共用 performClick，没有隐藏双击手势。
  const androidRow = android.slice(
    android.indexOf("private View bindAllFilesRow"),
    android.indexOf("private void styleLibraryToggle")
  );
  assert.match(androidRow, /nativeButton\("预览", false\)/);
  assert.match(androidRow, /boundRow\.setOnClickListener/);
  assert.match(androidRow, /boundRow\.performClick\(\)/);
  assert.doesNotMatch(androidRow, /GestureDetector|onDoubleTap/);

  assert.match(harmony, /private AllFilesRow\(item: PhotoItem\)/);
  assert.match(harmony, /Button\(this\.tr\('预览'\)/);
  assert.match(harmony, /Row\(\{ space: 8 \}\)[\s\S]{0,1800}Button\(this\.tr\('预览'/);
  assert.match(harmony, /Button\(this\.tr\('移动到项目'/);
});

test("Android all-files search uses recycled rows and bounded thumbnails", async () => {
  const [, android] = await readMobile();

  assert.match(android, /ListView list = new ListView\(this\)/);
  assert.match(android, /private final class LibraryFileListAdapter extends BaseAdapter/);
  assert.match(android, /private View bindAllFilesRow\(View convertView, File file\)/);
  assert.match(android, /if \(wrapper == null\)/);
  assert.match(android, /holder = \(LibraryFileRowHolder\) wrapper\.getTag\(\)/);
  assert.match(android, /private void loadLibraryThumbnailAsync/);
  assert.match(android, /libraryExecutor\.execute/);
  assert.match(android, /mainHandler\.post\(/);
  assert.match(android, /mainHandler\.postDelayed\(librarySearchRefreshRunnable, 150\)/);
  assert.match(android, /inJustDecodeBounds = true/);
  assert.match(android, /inSampleSize = Math\.max\(1, sample\)/);
  assert.match(android, /LIBRARY_THUMBNAIL_CACHE_LIMIT = 64/);
  assert.match(android, /target\.setTag\(key\)/);
  assert.match(android, /key\.equals\(target\.getTag\(\)\)/);
  assert.match(android, /button\.setSelected\(active\)/);
  assert.match(android, /button\.setStateDescription\(state\)/);
  assert.match(android, /button\.setContentDescription/);
  assert.match(android, /setTitle\(tr\("删除文件？"\)\)/);
  assert.match(android, /将永久删除所选文件，此操作无法撤销。/);
});

test("all-files rows can move metadata to any project or unclassified", async () => {
  const [ios, android, harmony] = await readMobile();

  assert.match(ios, /private func moveLibraryItem/);
  assert.match(ios, /branchStore\.assign\(item\.id, to: branchID\)/);
  assert.match(ios, /flattenBranchChoices\(branch\.children/);

  assert.match(android, /private void showMoveLibraryFileDialog\(File file\)/);
  assert.match(android, /setSingleChoiceItems/);
  assert.match(android, /libraryFileAssignments\.put\(file\.getAbsolutePath\(\), branchId\)/);
  assert.match(android, /libraryFileAssignments\.remove\(file\.getAbsolutePath\(\)\)/);
  assert.match(android, /saveLibraryFileAssignments\(\)/);

  assert.match(harmony, /private showMoveLibraryFileDialog\(item: PhotoItem\)/);
  assert.match(harmony, /TextPickerDialog\.show/);
  assert.match(harmony, /this\.assignPhotoToBranch\(item\.path, branchId\)/);
  assert.match(harmony, /this\.appendLibraryBranchChoices\(\s*branch\.children/);
});

test("all-files lists are bounded and source groups start collapsed", async () => {
  const [ios, android, harmony] = await readMobile();

  assert.match(ios, /visibleAllFiles\.prefix\(allFilesVisibleLimit\)/);
  assert.match(ios, /allFilesVisibleLimit \+= 12/);
  assert.match(ios, /systemAlbumExpanded = false/);
  assert.match(ios, /wirelessExpanded = false/);
  assert.match(ios, /cameraStorageExpanded = false/);

  assert.match(android, /LIBRARY_FILE_PAGE_SIZE = 12/);
  assert.match(android, /return shownCount\(\) \+ \(hasActionRow\(\) \? 1 : 0\)/);
  assert.match(android, /libraryVisibleLimit \+= LIBRARY_FILE_PAGE_SIZE/);
  assert.match(
    android,
    /"wireless-transfer"[\s\S]{0,520}buildWirelessTransferPanel\(\),\s*false/
  );
  const androidSystemAlbum = android.slice(
    android.indexOf('collapsibleGroupLocalizedLazy(\n                "system-album"'),
    android.indexOf('collapsibleGroupLocalizedLazy(\n                "system-album"') + 3_200
  );
  assert.match(androidSystemAlbum, /false\)\);/);
  const androidCameraStorage = android.slice(
    android.indexOf("private View buildCameraStoragePanel"),
    android.indexOf("private TextView emptyStorageText")
  );
  assert.match(androidCameraStorage, /collapsibleGroupLocalizedLazy\(/);
  assert.match(androidCameraStorage, /false\);/);

  assert.match(harmony, /systemExpanded: boolean = false/);
  assert.match(harmony, /cameraStorageExpanded: boolean = false/);
  assert.match(harmony, /wirelessExpanded: boolean = false/);
  assert.match(harmony, /Math\.min\(520, Math\.max\(192,/);
});

test("Android and Harmony category summaries include root and unclassified counts", async () => {
  const [, android, harmony] = await readMobile();

  assert.match(android, /localizedFormat\(\s*"%1\$d 个根分支 · %2\$d 个未分类文件"/);
  assert.match(android, /userLibraryBranches\.size\(\)/);
  assert.match(android, /countUnclassifiedLibraryFiles\(files\)/);
  assert.match(harmony, /this\.trf\(\s*'项目分类 · \{0\} 个根分支 · \{1\} 个未分类文件'/);
  assert.match(harmony, /this\.userLibraryBranches\.length/);
  assert.match(harmony, /this\.unclassifiedPhotos\(\)\.length/);
});

test("dynamic library copy is translated before interpolation", async () => {
  const [ios, android, harmony] = await readMobile();
  const [androidLoc, harmonyLoc] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/Localization.java"),
    read("native/harmony/entry/src/main/ets/localization/Localization.ets"),
  ]);

  assert.match(ios, /RuntimeLocalization\.format\(\s*"%lld 个根分支 · %lld 个未分类文件"/);
  assert.match(ios, /RuntimeLocalization\.format\(\s*"相机机内存储 · %lld"/);
  assert.match(android, /private String localizedFormat\(String messageTemplate, Object\.\.\. values\)/);
  assert.match(android, /localizedFormat\(\s*"%1\$d 个根分支 · %2\$d 个未分类文件"/);
  assert.match(androidLoc, /add\("%1\$d 个根分支 · %2\$d 个未分类文件"/);
  assert.match(harmony, /private trf\(source: string, values: Array<string>\): string/);
  assert.match(harmony, /this\.trf\(\s*'项目分类 · \{0\} 个根分支 · \{1\} 个未分类文件'/);
  assert.match(harmonyLoc, /export function translateTemplate/);
});

test("iOS all-files thumbnails are asynchronously downsampled and bounded", async () => {
  const [ios] = await readMobile();

  assert.match(ios, /import ImageIO/);
  assert.match(ios, /private final class LibraryThumbnailCache/);
  assert.match(ios, /cache\.countLimit = 96/);
  assert.match(ios, /cache\.totalCostLimit = 48 \* 1_024 \* 1_024/);
  assert.match(ios, /Task\.detached\(priority: \.utility\)/);
  assert.match(ios, /kCGImageSourceCreateThumbnailFromImageAlways: true/);
  assert.match(ios, /kCGImageSourceThumbnailMaxPixelSize: maxPixelSize/);
  assert.match(ios, /\.task\(id: requestIdentity\)/);
  const allFileRow = ios.slice(
    ios.indexOf("private func allFileRow"),
    ios.indexOf("private var moreToolsSection"),
  );
  assert.doesNotMatch(allFileRow, /UIImage\(contentsOfFile:/);
});

test("dangling project assignments are pruned and count as unclassified", async () => {
  const [ios, , harmony] = await readMobile();

  assert.match(ios, /assignments = saved\.filter \{ validIDs\.contains\(\$0\.value\) \}/);
  assert.match(ios, /if assignments\.count != saved\.count \{\s*persistAssignments\(\)/);
  assert.match(ios, /allBranchIDs\(in: branches\)\.contains\(branchID\)/);
  assert.match(harmony, /parsedAssignments\.filter\([\s\S]{0,360}this\.findLibraryBranch\([\s\S]{0,120}assignment\.branchId/);
  assert.match(harmony, /if \(this\.libraryFileAssignments\.length !== parsedAssignments\.length\)/);
  assert.match(harmony, /private branchIdForPhoto\(path: string\): string/);
  const harmonyBranchLookup = harmony.slice(
    harmony.indexOf("private branchIdForPhoto"),
    harmony.indexOf("private photosForBranch")
  );
  assert.match(harmonyBranchLookup, /this\.findLibraryBranch\([\s\S]{0,160}assignment\.branchId/);
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
  assert.match(iosEn, /^"移动到项目" = "Move to Project";$/m);
  assert.match(iosEn, /^"去拍摄" = "Go to Capture";$/m);
  assert.match(iosJa, /^"文件" = "ファイル";$/m);
  assert.match(iosJa, /^"所有文件" = "すべてのファイル";$/m);
  assert.match(iosJa, /^"项目分类" = "プロジェクト分類";$/m);
  assert.match(iosJa, /^"更多工具" = "その他のツール";$/m);
  assert.match(iosJa, /^"移动到项目" = "プロジェクトに移動";$/m);
  assert.match(iosZh, /^"文件" = "文件";$/m);
  assert.match(iosZh, /^"文件库" = "文件库";$/m);
  assert.match(iosZh, /^"所有文件" = "所有文件";$/m);
  assert.match(iosZh, /^"项目分类" = "项目分类";$/m);
  assert.match(iosZh, /^"更多工具" = "更多工具";$/m);
  assert.match(iosZh, /^"移动到项目" = "移动到项目";$/m);

  // Android Localization：add(zh, en, ja) 三语键值对
  assert.match(androidLoc, /add\("文件", "Files", "ファイル"\)/);
  assert.match(androidLoc, /add\("文件库", "Library", "ライブラリ"\)/);
  assert.match(androidLoc, /add\("所有文件", "All Files", "すべてのファイル"\)/);
  assert.match(androidLoc, /add\("项目分类", "Project Categories", "プロジェクト分類"\)/);
  assert.match(androidLoc, /add\("更多工具", "More Tools", "その他のツール"\)/);
  assert.match(androidLoc, /add\("未分类", "Unclassified", "未分類"\)/);
  assert.match(androidLoc, /add\("移动到项目", "Move to Project", "プロジェクトに移動"\)/);
  assert.match(androidLoc, /add\("已选择", "Selected", "選択済み"\)/);
  assert.match(androidLoc, /add\("导出副本", "Export Copy", "コピーを書き出す"\)/);

  for (const strings of [iosZh, iosEn, iosJa]) {
    assert.match(strings, /"文件已删除"\s*=/);
    assert.match(strings, /"删除失败"\s*=/);
  }

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
  assert.match(
    harmonyLoc,
    /new TranslationEntry\('移动到项目', 'Move to Project', 'プロジェクトに移動'\)/
  );
  assert.match(
    harmonyLoc,
    /new TranslationEntry\('导出副本', 'Export Copy', 'コピーを書き出す'\)/
  );
});

test("first-level navigation renamed from 分支 to 文件 on mobile", async () => {
  const [ios, android, harmony] = await readMobile();
  const iosModel = await read("native/ios/NikonLink/Models/AppModel.swift");

  assert.match(ios, /navTab\(\.library, title: "文件"\)/);
  // 宽屏 SideNavigation 走 displayTitle（rawValue 保持兼容）
  assert.match(iosModel, /case \.library: return "文件"/);
  assert.doesNotMatch(ios, /navTab\(\.library, title: "分支"\)/);
  assert.doesNotMatch(ios, /Label\("分支", systemImage: AppSection\.library\.icon\)/);

  assert.match(android, /navButton\("文件", "library"\)/);
  assert.doesNotMatch(android, /navButton\("分支", "library"\)/);

  assert.match(harmony, /this\.NavButton\('文件', 'library'\)/);
  assert.doesNotMatch(harmony, /this\.NavButton\('分支', 'library'\)/);
});
