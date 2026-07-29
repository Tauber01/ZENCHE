import { CameraService } from "./camera-service.js";
import { PhotoStorage } from "./storage-service.js";

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

const camera = new CameraService();
const storage = new PhotoStorage();
const storageReady = storage.init();

const body = document.body;
const commandDialog = $("#commandDialog");
const commandTrigger = $("#commandTrigger");
const commandSearch = $("#commandSearch");
const connectionDialog = $("#connectionDialog");
const cameraChip = $("#cameraChip");
const cameraScene = $("#cameraScene");
const viewfinder = $("#viewfinder");
const liveVideo = $("#liveVideo");
const monitorVideo = $("#monitorVideo");
const nativePreview = $("#nativePreview");
const nativeMonitorPreview = $("#nativeMonitorPreview");
const monitorFrame = $(".monitor-stage__frame");
const shutterButton = $("#shutterButton");
const captureFlash = $("#captureFlash");
const fileGrid = $("#fileGrid");
const transferList = $("#transferList");
const fileInput = $("#fileInput");
const downloadButtons = [$("#downloadButton"), $("#inspectorDownload")];
const deleteButton = $("#deleteButton");
const selectAllButton = $("#selectAllButton");
const undoToast = $("#undoToast");
const undoButton = $("#undoButton");
const toastMessage = $("#toastMessage");
const runtimeNotice = $("#runtimeNotice");
const runtimeNoticeText = $("#runtimeNoticeText");
const runtimeNoticeAction = $("#runtimeNoticeAction");
const liveStatus = $(".live-status");
const connectButton = $("#connectButton");
const deviceField = $("#deviceField");
const videoDeviceSelect = $("#videoDeviceSelect");
const connectionNotice = $("#connectionNotice");

const state = {
  mode: "simple",
  view: "capture",
  zoom: 100,
  sessionCaptures: 0,
  sessionBytes: 0,
  selectedIds: new Set(),
  records: new Map(),
  libraryUrls: new Map(),
  queueUrls: new Set(),
  removedRecords: [],
  filter: "all",
  toastTimer: null,
  selectedCommandIndex: 0,
  connectionMode: "media",
  liveEnabled: true,
  queuePaused: false,
  deferredInstallPrompt: null,
  wakeLock: null,
};

const modeCopy = {
  simple: {
    label: "普通模式",
    description: "连接相机、确认构图，然后完成照片拍摄。",
  },
  pro: {
    label: "专业模式",
    description: "照片控制 · 曝光、对焦、白平衡与快门。",
  },
};

const constraintLabels = {
  continuous: "连续 / 自动",
  manual: "手动",
  "single-shot": "单次",
  none: "关闭",
};

const safeStore = (key, value) => {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Private browsing can disable storage.
  }
};

const safeRead = (key) => {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
};

const formatBytes = (bytes) => {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** index;
  return `${value.toFixed(index === 0 || value >= 100 ? 0 : 1)} ${units[index]}`;
};

const formatTime = (dateValue) => {
  const date = new Date(dateValue);
  const elapsed = Date.now() - date.getTime();
  if (elapsed < 60_000) return "刚刚";
  if (elapsed < 3_600_000) return `${Math.floor(elapsed / 60_000)} 分钟前`;
  if (date.toDateString() === new Date().toDateString()) {
    return date.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
  }
  return date.toLocaleDateString("zh-CN", { month: "2-digit", day: "2-digit" });
};

const filenameForBlob = (blob) => {
  const extension = blob.type === "image/png" ? "png" : "jpg";
  const timestamp = new Date().toISOString().replace(/\D/g, "").slice(0, 14);
  return `NIKON_${timestamp}.${extension}`;
};

const setButtonBusy = (button, busy) => {
  if (!button) return;
  button.toggleAttribute("aria-busy", busy);
  if (busy) button.dataset.state = "loading";
  else delete button.dataset.state;
};

const setRuntimeNotice = (message = "", actionLabel = "", action = null) => {
  runtimeNotice.hidden = !message;
  runtimeNoticeText.textContent = message;
  runtimeNoticeAction.hidden = !actionLabel;
  runtimeNoticeAction.textContent = actionLabel;
  runtimeNoticeAction.onclick = action;
};

const hideToast = () => {
  clearTimeout(state.toastTimer);
  state.toastTimer = null;
  state.removedRecords = [];
  undoToast.hidden = true;
};

const showToast = (message, removedRecords = []) => {
  clearTimeout(state.toastTimer);
  state.removedRecords = removedRecords;
  toastMessage.textContent = message;
  undoButton.hidden = removedRecords.length === 0;
  undoToast.hidden = false;
  state.toastTimer = window.setTimeout(hideToast, removedRecords.length ? 12_000 : 4200);
};

const setMode = (mode) => {
  state.mode = mode === "pro" ? "pro" : "simple";
  body.dataset.experience = state.mode;
  $$("[data-experience-value]").forEach((button) => {
    const active = button.dataset.experienceValue === state.mode;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  $("#modeDescription").textContent = modeCopy[state.mode].description;
  $("#inspectorModeLabel").textContent = modeCopy[state.mode].label;
  safeStore("nikon-link-mode", state.mode);
};

const setView = (view) => {
  const allowed = ["capture", "monitor", "library", "transfer"];
  state.view = allowed.includes(view) ? view : "capture";
  body.dataset.view = state.view;

  $$("[data-view-target]").forEach((button) => {
    const active = button.dataset.viewTarget === state.view;
    button.classList.toggle("is-active", active);
    button.toggleAttribute("aria-current", active);
  });
  $$("[data-view-panel]").forEach((panel) => {
    const active = panel.dataset.viewPanel === state.view;
    panel.hidden = !active;
    panel.classList.toggle("is-active", active);
  });
  $$("[data-inspector-panel]").forEach((panel) => {
    const active = panel.dataset.inspectorPanel === state.view;
    panel.hidden = !active;
    panel.classList.toggle("is-active", active);
  });
  $(".workspace")?.scrollTo({ top: 0, behavior: "instant" });
};

const openDialog = (dialog, firstFocus) => {
  if (!dialog || dialog.open) return;
  if (typeof dialog.showModal === "function") dialog.showModal();
  else dialog.setAttribute("open", "");
  window.setTimeout(() => firstFocus?.focus(), 0);
};

const closeDialog = (dialog) => {
  if (!dialog?.open) return;
  if (typeof dialog.close === "function") dialog.close();
  else dialog.removeAttribute("open");
};

const refreshStorageEstimate = async () => {
  const value = $("#storageRemaining");
  if (!navigator.storage?.estimate) {
    value.textContent = "由系统管理";
    return;
  }
  try {
    const { quota = 0, usage = 0 } = await navigator.storage.estimate();
    value.textContent = quota ? `约 ${formatBytes(Math.max(0, quota - usage))}` : "由系统管理";
  } catch {
    value.textContent = "由系统管理";
  }
};

const clearLibraryUrls = () => {
  state.libraryUrls.forEach((url) => URL.revokeObjectURL(url));
  state.libraryUrls.clear();
};

const makeIcon = (iconId) => {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.classList.add("icon");
  const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
  use.setAttribute("href", `#${iconId}`);
  svg.append(use);
  return svg;
};

const createPhotoCard = (record) => {
  const card = document.createElement("button");
  card.className = "file-card";
  card.type = "button";
  card.dataset.photoId = record.id;
  card.setAttribute("aria-selected", String(state.selectedIds.has(record.id)));

  const thumb = document.createElement("span");
  thumb.className = "file-card__thumb";
  const canPreview = record.type?.startsWith("image/") && !/\.(nef|nrw)$/i.test(record.name);
  if (canPreview) {
    const image = new Image();
    const url = URL.createObjectURL(record.blob);
    state.libraryUrls.set(record.id, url);
    image.src = url;
    image.alt = "";
    image.addEventListener("load", () => thumb.classList.add("has-image"), { once: true });
    image.addEventListener("error", () => image.remove(), { once: true });
    thumb.append(image);
  }

  const meta = document.createElement("span");
  meta.className = "file-card__meta";
  const name = document.createElement("strong");
  name.textContent = record.name;
  const detail = document.createElement("small");
  detail.textContent = `${formatBytes(record.size)} · ${formatTime(record.capturedAt)}`;
  meta.append(name, detail);

  const check = document.createElement("span");
  check.className = "file-card__check";
  check.append(makeIcon("icon-check"));
  card.append(thumb, meta, check);
  return card;
};

const visibleRecords = () =>
  [...state.records.values()].filter((record) => {
    if (state.filter === "all") return true;
    if (state.filter === "camera") return record.source === "camera";
    return record.source === "import";
  });

const updateSelection = () => {
  const selectedRecords = [...state.selectedIds]
    .map((id) => state.records.get(id))
    .filter(Boolean);
  const amount = selectedRecords.length;
  const bytes = selectedRecords.reduce((sum, record) => sum + record.size, 0);
  $("#selectionCount").textContent = amount ? `已选择 ${amount} 个文件` : "未选择文件";
  $("#selectedFilesValue").textContent = `${amount} 项`;
  $("#selectedSizeValue").textContent = amount ? formatBytes(bytes) : "—";
  [...downloadButtons, deleteButton].forEach((button) => {
    button.disabled = amount === 0;
  });
  const displayed = visibleRecords();
  selectAllButton.disabled = displayed.length === 0;
  selectAllButton.textContent =
    displayed.length > 0 && displayed.every((record) => state.selectedIds.has(record.id))
      ? "取消全选"
      : "全选";
  $$(".file-card", fileGrid).forEach((card) => {
    card.setAttribute("aria-selected", String(state.selectedIds.has(card.dataset.photoId)));
  });
};

const renderLibrary = async () => {
  const records = await storage.list();
  state.records = new Map(records.map((record) => [record.id, record]));
  state.selectedIds = new Set([...state.selectedIds].filter((id) => state.records.has(id)));
  clearLibraryUrls();
  $$(".file-card", fileGrid).forEach((card) => card.remove());

  const displayed = visibleRecords();
  displayed.forEach((record) => fileGrid.append(createPhotoCard(record)));
  $("#libraryEmptyState").hidden = displayed.length > 0;
  $("#fileBadge").textContent = String(records.length);
  updateSelection();
  await refreshStorageEstimate();
};

const addQueueRecord = (record) => {
  $("#transferEmptyState").hidden = true;
  const row = document.createElement("div");
  row.className = "transfer-row is-complete";
  row.dataset.photoId = record.id;

  const preview = document.createElement("span");
  preview.className = "transfer-row__preview";
  if (record.type?.startsWith("image/") && !/\.(nef|nrw)$/i.test(record.name)) {
    const image = new Image();
    const url = URL.createObjectURL(record.blob);
    state.queueUrls.add(url);
    image.src = url;
    image.alt = "";
    image.addEventListener("load", () => preview.classList.add("has-image"), { once: true });
    image.addEventListener("error", () => image.remove(), { once: true });
    preview.append(image);
  }

  const main = document.createElement("div");
  main.className = "transfer-row__main";
  const top = document.createElement("div");
  const name = document.createElement("strong");
  name.textContent = record.name;
  const status = document.createElement("span");
  status.textContent = "已保存到本地";
  top.append(name, status);
  const progress = document.createElement("progress");
  progress.max = 100;
  progress.value = 100;
  main.append(top, progress);

  const size = document.createElement("span");
  size.className = "transfer-row__speed";
  size.textContent = formatBytes(record.size);
  row.append(preview, main, size);
  transferList.prepend(row);

  state.sessionBytes += record.size;
  $("#sessionBytes").textContent = formatBytes(state.sessionBytes);
  $("#activeTransferCount").textContent = "0";
  $("#waitingTransferCount").textContent = "0";
};

const downloadRecord = (record) => {
  const url = URL.createObjectURL(record.blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = record.name;
  anchor.hidden = true;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
};

const downloadSelected = async (trigger) => {
  if (!state.selectedIds.size) return;
  downloadButtons.forEach((button) => setButtonBusy(button, true));
  try {
    const records = [...state.selectedIds]
      .map((id) => state.records.get(id))
      .filter(Boolean);
    records.forEach(downloadRecord);
    showToast(`已开始下载 ${records.length} 个文件。`);
  } finally {
    downloadButtons.forEach((button) => setButtonBusy(button, false));
    if (trigger) trigger.dataset.state = "success";
    window.setTimeout(() => {
      if (trigger) delete trigger.dataset.state;
    }, 800);
  }
};

const removeSelected = async () => {
  const records = [...state.selectedIds]
    .map((id) => state.records.get(id))
    .filter(Boolean);
  if (!records.length) return;
  await storage.remove(records.map((record) => record.id));
  state.selectedIds.clear();
  await renderLibrary();
  showToast(`已从本地照片库移除 ${records.length} 个文件。`, records);
};

const undoRemove = async () => {
  const records = [...state.removedRecords];
  if (!records.length) return;
  clearTimeout(state.toastTimer);
  await storage.putMany(records);
  state.removedRecords = [];
  undoToast.hidden = true;
  await renderLibrary();
  showToast(`已恢复 ${records.length} 个文件。`);
};

const importFiles = async (files) => {
  if (!files?.length) return;
  const button = $("#importFilesButton");
  setButtonBusy(button, true);
  try {
    const records = await storage.importFiles(files);
    records.forEach(addQueueRecord);
    await renderLibrary();
    showToast(`已导入 ${records.length} 个文件到本地照片库。`);
  } catch (error) {
    showToast(`导入失败：${error.message}`);
  } finally {
    setButtonBusy(button, false);
    fileInput.value = "";
  }
};

const updateReadouts = () => {
  const settings = camera.settings || {};
  const exposureTime = settings.exposureTime;
  $("#readoutShutter").textContent = exposureTime
    ? exposureTime < 1
      ? `1/${Math.round(1 / exposureTime)}`
      : `${exposureTime}s`
    : "—";
  $("#readoutAperture").textContent = settings.aperture ? `F${settings.aperture}` : "—";
  $("#readoutIso").textContent = settings.iso ? `ISO ${Math.round(settings.iso)}` : "—";
  const compensation = settings.exposureCompensation;
  $("#readoutExposure").textContent =
    compensation === undefined ? "—" : `${compensation > 0 ? "+" : ""}${compensation} EV`;
};

const updateMonitorDetails = () => {
  const settings = camera.settings || {};
  const width = settings.width || liveVideo.videoWidth;
  const height = settings.height || liveVideo.videoHeight;
  $("#monitorResolution").textContent = width && height ? `${width} × ${height}` : "—";
  $("#monitorFrameRate").textContent = settings.frameRate
    ? `${Math.round(settings.frameRate)} fps`
    : camera.mode === "demo"
      ? "静态演示"
      : "—";
  $("#monitorTrackState").textContent =
    camera.mode === "demo"
      ? "演示源就绪"
      : camera.mode === "native"
        ? "Nikon PTP 会话正常"
        : camera.track?.readyState === "live"
          ? "视频流正常"
          : "未连接";
};

const supportsCapability = (name) =>
  ["media", "native"].includes(camera.mode) && camera.capabilities[name] !== undefined;

const populateSelectFromCapability = (select, capability) => {
  const name = select.dataset.constraint;
  if (Array.isArray(capability)) {
    select.replaceChildren(
      ...capability.map((value) => {
        const option = document.createElement("option");
        option.value = String(value);
        option.textContent = constraintLabels[value] || String(value);
        return option;
      }),
    );
  } else if (
    name === "focusDistance" &&
    capability &&
    typeof capability === "object" &&
    Number.isFinite(capability.min) &&
    Number.isFinite(capability.max)
  ) {
    const range = capability.max - capability.min;
    select.replaceChildren(
      ...Array.from({ length: 5 }, (_, index) => {
        const value = capability.min + (range * index) / 4;
        const option = document.createElement("option");
        option.value = String(value);
        option.textContent = index === 0 ? "近" : index === 4 ? "远" : `${Math.round(index * 25)}%`;
        return option;
      }),
    );
  }
};

const applyCapabilityState = () => {
  $$("[data-capability]").forEach((container) => {
    const name = container.dataset.capability;
    const supported = supportsCapability(name);
    container.classList.toggle("is-unsupported", !supported);
    container.title = supported ? "" : "当前视频设备未开放此参数";
    $$("button, select, input", container).forEach((control) => {
      control.disabled = !supported;
    });
    const select = $("select[data-constraint]", container);
    if (supported && select) {
      populateSelectFromCapability(select, camera.capabilities[name]);
      const current = camera.settings[name];
      if (current !== undefined) select.value = String(current);
    }
  });

  $("#simpleAutofocusSwitch").disabled = !supportsCapability("focusMode");
  $("#blurSlider").disabled = !supportsCapability("focusDistance");
  $("#brightnessSlider").disabled = !supportsCapability("exposureCompensation");
  $("#scenePreset").disabled = !(
    supportsCapability("focusMode") ||
    supportsCapability("exposureMode") ||
    supportsCapability("whiteBalanceMode")
  );
  $$("[data-focus-param]").forEach((button) => {
    const capabilityMap = {
      aperture: "focusDistance",
      brightness: "exposureCompensation",
      whitebalance: "whiteBalanceMode",
    };
    button.disabled = !supportsCapability(capabilityMap[button.dataset.focusParam]);
  });
  updateReadouts();
};

const setSourceUi = (mode) => {
  const realStream = mode === "media";
  const native = mode === "native";
  const demo = mode === "demo";
  viewfinder.classList.toggle("is-streaming", realStream || native);
  monitorFrame.classList.toggle("is-streaming", realStream || native);
  liveVideo.hidden = !realStream;
  monitorVideo.hidden = !realStream;
  nativePreview.hidden = !native;
  nativeMonitorPreview.hidden = !native;
  cameraScene.classList.remove("is-off");
  shutterButton.disabled = !(realStream || native || demo);
  liveStatus.hidden = !(realStream || native || demo) || !state.liveEnabled;
  $("#liveStatusText").textContent = demo ? "DEMO" : native ? "NIKON LIVE" : "LIVE";
  $("#pictureInPictureButton").disabled = !realStream || !document.pictureInPictureEnabled;

  const label = camera.device?.label || (demo ? "内置演示场景" : "未连接");
  $("#cameraName").textContent = demo ? "演示场景" : label;
  $("#cameraConnection").textContent = demo
    ? "本地功能测试"
    : native
      ? "USB · 原生 PTP"
      : "系统视频流已连接";
  $("#monitorDeviceLabel").textContent = label;
  $("#monitorStatus").textContent = demo
    ? "演示画面已就绪"
    : native
      ? "Nikon 实时取景已就绪"
      : "实时视频流已就绪";
  $("#connectionStatus").lastChild.textContent = demo ? " 演示源已连接" : ` ${label}`;
  $("#viewfinderStatus").textContent =
    demo ? "DEMO READY" : native ? "NIKON · PTP LIVE" : "LIVE READY";

  const width = camera.settings.width;
  const height = camera.settings.height;
  const fps = camera.settings.frameRate;
  $("#viewfinderFormat").textContent =
    width && height ? `${width}×${height}${fps ? ` ${Math.round(fps)}P` : ""}` : "视频流";
  $("#viewfinderCodec").textContent = demo
    ? "本地演示图像"
    : native
      ? "Nikon PTP / JPEG"
      : "UVC / MediaStream";
  $("#cameraMeta span").textContent = width && height ? `${width}×${height}` : "已连接";
  updateMonitorDetails();
  applyCapabilityState();
};

const setDisconnectedUi = (message = "未连接") => {
  viewfinder.classList.remove("is-streaming");
  monitorFrame.classList.remove("is-streaming");
  liveVideo.hidden = true;
  monitorVideo.hidden = true;
  nativePreview.hidden = true;
  nativeMonitorPreview.hidden = true;
  nativePreview.removeAttribute("src");
  nativeMonitorPreview.removeAttribute("src");
  shutterButton.disabled = true;
  liveStatus.hidden = true;
  $("#cameraName").textContent = "未连接";
  $("#cameraConnection").textContent = "选择相机设备";
  $("#cameraMeta span").textContent = "—";
  $("#monitorDeviceLabel").textContent = message;
  $("#monitorStatus").textContent = "等待设备连接";
  $("#connectionStatus").lastChild.textContent = ` ${message}`;
  $("#viewfinderStatus").textContent = "NO SOURCE";
  $("#viewfinderFormat").textContent = "—";
  $("#viewfinderCodec").textContent = "浏览器视频流";
  camera.settings = {};
  updateMonitorDetails();
  applyCapabilityState();
};

const capturePhoto = async () => {
  if (shutterButton.disabled) {
    await openConnectionDialog();
    return;
  }
  if (shutterButton.dataset.state === "loading") return;

  setButtonBusy(shutterButton, true);
  captureFlash.classList.remove("is-active");
  void captureFlash.offsetWidth;
  captureFlash.classList.add("is-active");

  try {
    const blob = await camera.capture(liveVideo);
    const filename = filenameForBlob(blob);
    state.sessionCaptures += 1;
    $("#captureCount").textContent = String(state.sessionCaptures);
    $("#lastCapture").textContent = `上次拍摄 ${filename} · 刚刚`;

    if ($("#autoSaveSwitch").checked && !state.queuePaused) {
      const record = await storage.saveBlob(blob, {
        name: filename,
        source: "camera",
        metadata: {
          device: camera.device?.label || "演示场景",
          sourceMode: camera.mode,
          settings: camera.settings,
        },
      });
      addQueueRecord(record);
      await renderLibrary();
    } else {
      downloadRecord({
        name: filename,
        blob,
      });
      showToast(
        state.queuePaused
          ? "保存队列已暂停，照片已直接下载。"
          : "照片未进入本地照片库，已直接下载。",
      );
    }

    shutterButton.dataset.state = "success";
    navigator.storage?.persist?.().catch(() => {});
  } catch (error) {
    showToast(`拍摄失败：${error.message}`);
  } finally {
    shutterButton.removeAttribute("aria-busy");
    window.setTimeout(() => delete shutterButton.dataset.state, 650);
  }
};

const populateVideoDevices = async (preferredId = "") => {
  const current = preferredId || videoDeviceSelect.value;
  let devices = [];
  try {
    devices = await camera.listVideoDevices();
  } catch {
    // Permission may not have been granted yet.
  }
  const automatic = document.createElement("option");
  automatic.value = "";
  automatic.textContent = "由系统选择";
  videoDeviceSelect.replaceChildren(automatic);
  devices.forEach((device, index) => {
    const option = document.createElement("option");
    option.value = device.deviceId;
    option.textContent = device.label || `视频设备 ${index + 1}`;
    videoDeviceSelect.append(option);
  });
  if ($(`option[value="${CSS.escape(current)}"]`, videoDeviceSelect)) {
    videoDeviceSelect.value = current;
  }
  $("#deviceHelper").textContent = devices.length
    ? `发现 ${devices.length} 个视频设备。`
    : "连接时浏览器会请求相机权限。";
};

const updateConnectionChoice = (mode) => {
  state.connectionMode = mode;
  $$(".connection-option").forEach((option) => {
    const selected = option.dataset.connection === mode;
    option.classList.toggle("is-selected", selected);
    option.setAttribute("aria-pressed", String(selected));
  });
  deviceField.hidden = mode !== "media";
  const labels = {
    native: "连接 EXPEED 7 相机",
    media: "连接视频设备",
    webusb: "检测 Nikon USB",
    demo: "进入演示",
  };
  connectButton.textContent = labels[mode];
  connectionNotice.textContent =
    mode === "native"
      ? "请用 USB 数据线直连支持的 Nikon EXPEED 7 相机，并选择 MTP/PTP 模式。"
      : mode === "webusb"
      ? "只读取设备身份，不会发送拍摄或参数指令。"
      : mode === "demo"
        ? "使用内置场景，可完整测试拍摄、保存、下载和删除。"
        : "仅在用户点击连接后请求设备权限。";
};

const openConnectionDialog = () => {
  updateConnectionChoice(state.connectionMode);
  openDialog(connectionDialog, connectionDialog.querySelector(".connection-option.is-selected"));
  if (state.connectionMode === "media") {
    populateVideoDevices(camera.device?.id || "").catch((error) => {
      connectionNotice.textContent = `无法读取视频设备：${error.message}`;
      connectionNotice.dataset.tone = "error";
    });
  }
};

const connectSelectedSource = async () => {
  setButtonBusy(connectButton, true);
  connectionNotice.textContent = "正在连接…";
  try {
    if (state.connectionMode === "webusb") {
      const device = await camera.detectNikonUsb();
      $("#cameraName").textContent = device.productName;
      $("#cameraConnection").textContent = "已识别 · 需要原生相机适配";
      $("#cameraMeta span").textContent = `PID ${device.productId.toString(16).toUpperCase()}`;
      showToast(`已识别 ${device.productName}，尚未发送相机控制指令。`);
      closeDialog(connectionDialog);
      return;
    }

    if (state.connectionMode === "native") {
      await camera.connectNative();
      camera.detachVideo(liveVideo);
      camera.detachVideo(monitorVideo);
      setSourceUi("native");
      await camera.startNativePreview((dataUrl, frame) => {
        nativePreview.src = dataUrl;
        nativeMonitorPreview.src = dataUrl;
        if (frame.width && frame.height) {
          camera.settings = { ...camera.settings, width: frame.width, height: frame.height };
          updateMonitorDetails();
        }
      });
    } else if (state.connectionMode === "demo") {
      camera.connectDemo();
      camera.detachVideo(liveVideo);
      camera.detachVideo(monitorVideo);
      setSourceUi("demo");
    } else {
      const result = await camera.connectMedia(videoDeviceSelect.value);
      await Promise.all([camera.attachVideo(liveVideo), camera.attachVideo(monitorVideo)]);
      setSourceUi("media");
      await populateVideoDevices(result.device.id);
    }
    setRuntimeNotice("");
    closeDialog(connectionDialog);
  } catch (error) {
    connectionNotice.textContent = error.message;
    connectionNotice.dataset.tone = "error";
  } finally {
    setButtonBusy(connectButton, false);
  }
};

const applyConstraint = async (name, value, rollback) => {
  try {
    const applied = await camera.applyConstraint(name, value);
    updateReadouts();
    updateMonitorDetails();
    return applied;
  } catch (error) {
    rollback?.();
    showToast(error.message);
    return null;
  }
};

const updateDigitalZoom = async (direction) => {
  const capability = camera.capabilities.zoom;
  if (camera.mode === "media" && capability?.min !== undefined) {
    const current = camera.settings.zoom ?? capability.min;
    const step = capability.step || (capability.max - capability.min) / 10 || 1;
    const next = Math.min(capability.max, Math.max(capability.min, current + direction * step));
    const applied = await applyConstraint("zoom", next);
    if (applied !== null) $("#zoomValue").textContent = `${Number(applied).toFixed(1)}×`;
    return;
  }
  state.zoom = Math.min(200, Math.max(100, state.zoom + direction * 25));
  const scale = `scale(${state.zoom / 100})`;
  cameraScene.style.transform = scale;
  liveVideo.style.transform = scale;
  $("#zoomValue").textContent = `${state.zoom}%`;
};

const toggleTool = (button, target, hiddenClass) => {
  const active = button.getAttribute("aria-pressed") !== "true";
  button.setAttribute("aria-pressed", String(active));
  button.classList.toggle("is-active", active);
  target.classList.toggle(hiddenClass, !active);
};

const getVisibleCommands = () => $$(".command-item").filter((item) => !item.hidden);

const selectCommand = (index) => {
  const commands = getVisibleCommands();
  if (!commands.length) return;
  state.selectedCommandIndex = (index + commands.length) % commands.length;
  commands.forEach((item, itemIndex) => {
    const selected = itemIndex === state.selectedCommandIndex;
    item.classList.toggle("is-selected", selected);
    item.setAttribute("aria-selected", String(selected));
  });
  commands[state.selectedCommandIndex].scrollIntoView({ block: "nearest" });
};

const filterCommands = () => {
  const query = commandSearch.value.trim().toLocaleLowerCase("zh-CN");
  $$(".command-item").forEach((item) => {
    item.hidden = !item.textContent.toLocaleLowerCase("zh-CN").includes(query);
  });
  selectCommand(0);
};

const runCommand = (command) => {
  closeDialog(commandDialog);
  if (command === "capture") {
    setView("capture");
    window.setTimeout(capturePhoto, 80);
  } else if (command === "library") {
    setView("library");
  } else if (command === "monitor") {
    setView("monitor");
  } else if (command === "mode") {
    setMode(state.mode === "simple" ? "pro" : "simple");
  }
};

$$("[data-experience-value]").forEach((button) => {
  button.addEventListener("click", () => setMode(button.dataset.experienceValue));
});

$$("[data-view-target]").forEach((button) => {
  button.addEventListener("click", () => setView(button.dataset.viewTarget));
});

shutterButton.addEventListener("click", capturePhoto);
cameraChip.addEventListener("click", openConnectionDialog);
$("#settingsButton").addEventListener("click", openConnectionDialog);
$("#folderButton").addEventListener("click", () => setView("library"));
$("#moreCaptureButton").addEventListener("click", () => {
  commandSearch.value = "";
  filterCommands();
  openDialog(commandDialog, commandSearch);
});

fileGrid.addEventListener("click", (event) => {
  const card = event.target.closest(".file-card");
  if (!card) return;
  const id = card.dataset.photoId;
  if (state.selectedIds.has(id)) state.selectedIds.delete(id);
  else state.selectedIds.add(id);
  updateSelection();
});

selectAllButton.addEventListener("click", () => {
  const displayed = visibleRecords();
  const shouldSelect = !displayed.every((record) => state.selectedIds.has(record.id));
  displayed.forEach((record) => {
    if (shouldSelect) state.selectedIds.add(record.id);
    else state.selectedIds.delete(record.id);
  });
  updateSelection();
});

downloadButtons.forEach((button) => {
  button.addEventListener("click", () => downloadSelected(button));
});
deleteButton.addEventListener("click", removeSelected);
undoButton.addEventListener("click", undoRemove);

[$("#importFilesButton"), $("#emptyImportButton")].forEach((button) => {
  button.addEventListener("click", () => fileInput.click());
});
fileInput.addEventListener("change", () => importFiles([...fileInput.files]));

$$(".segmented__item").forEach((button, index) => {
  button.addEventListener("click", async () => {
    $$(".segmented__item").forEach((item) => {
      const selected = item === button;
      item.classList.toggle("is-active", selected);
      item.setAttribute("aria-selected", String(selected));
    });
    state.filter = ["all", "camera", "import"][index];
    await renderLibrary();
  });
});

$("#liveToggle").addEventListener("click", (event) => {
  state.liveEnabled = !state.liveEnabled;
  const button = event.currentTarget;
  button.setAttribute("aria-pressed", String(state.liveEnabled));
  button.classList.toggle("is-active", state.liveEnabled);
  if (camera.track) camera.track.enabled = state.liveEnabled;
  if (camera.mode === "native") {
    if (state.liveEnabled) {
      camera.startNativePreview((dataUrl) => {
        nativePreview.src = dataUrl;
        nativeMonitorPreview.src = dataUrl;
      }).catch((error) => showToast(error.message));
    } else {
      camera.stopNativePreview();
    }
  }
  cameraScene.classList.toggle("is-off", !state.liveEnabled);
  liveVideo.style.opacity = state.liveEnabled ? "1" : "0";
  monitorVideo.style.opacity = state.liveEnabled ? "1" : "0";
  nativePreview.style.opacity = state.liveEnabled ? "1" : "0";
  nativeMonitorPreview.style.opacity = state.liveEnabled ? "1" : "0";
  liveStatus.hidden = !state.liveEnabled || camera.mode === "disconnected";
});

$("#gridToggle").addEventListener("click", (event) => {
  toggleTool(event.currentTarget, $(".grid-overlay"), "is-hidden");
});
$("#histogramToggle").addEventListener("click", (event) => {
  toggleTool(event.currentTarget, $(".monitor-histogram"), "is-hidden");
});
$("#peakingToggle").addEventListener("click", (event) => {
  const button = event.currentTarget;
  const active = button.getAttribute("aria-pressed") !== "true";
  button.setAttribute("aria-pressed", String(active));
  button.classList.toggle("is-active", active);
  monitorFrame.classList.toggle("is-peaking", active);
});

$("#zoomOut").addEventListener("click", () => updateDigitalZoom(-1));
$("#zoomIn").addEventListener("click", () => updateDigitalZoom(1));

const blurLabels = ["清晰环境", "稍清晰", "适中", "柔和", "很虚化"];
const brightnessLabels = ["较暗", "稍暗", "自然", "稍亮", "明亮"];
$("#blurSlider").addEventListener("input", (event) => {
  $("#blurValue").textContent = blurLabels[Number(event.target.value)];
});
$("#blurSlider").addEventListener("change", async (event) => {
  const capability = camera.capabilities.focusDistance;
  if (!supportsCapability("focusDistance") || capability?.min === undefined) return;
  const ratio = Number(event.target.value) / 4;
  await applyConstraint("focusDistance", capability.max - ratio * (capability.max - capability.min));
});
$("#brightnessSlider").addEventListener("input", (event) => {
  const value = Number(event.target.value);
  $("#brightnessValue").textContent = brightnessLabels[value];
  const brightness = 0.84 + value * 0.08;
  cameraScene.style.filter = `brightness(${brightness})`;
  liveVideo.style.filter = `brightness(${brightness})`;
});
$("#brightnessSlider").addEventListener("change", async (event) => {
  const capability = camera.capabilities.exposureCompensation;
  if (!supportsCapability("exposureCompensation") || capability?.min === undefined) return;
  const ratio = Number(event.target.value) / 4;
  await applyConstraint(
    "exposureCompensation",
    capability.min + ratio * (capability.max - capability.min),
  );
});

$("#simpleAutofocusSwitch").addEventListener("change", (event) => {
  const capability = camera.capabilities.focusMode;
  if (!Array.isArray(capability)) return;
  const preferred = event.target.checked
    ? capability.includes("continuous")
      ? "continuous"
      : capability[0]
    : capability.includes("manual")
      ? "manual"
      : capability.at(-1);
  applyConstraint("focusMode", preferred, () => {
    event.target.checked = !event.target.checked;
  });
});

$("#scenePreset").addEventListener("change", async (event) => {
  const preset = event.target.value;
  const requests = [];
  const choose = (name, preferred) => {
    const capability = camera.capabilities[name];
    if (!supportsCapability(name) || !Array.isArray(capability)) return;
    const value = preferred.find((candidate) => capability.includes(candidate));
    if (value !== undefined) requests.push(applyConstraint(name, value));
  };

  if (preset === "手动控制") {
    choose("exposureMode", ["manual"]);
    choose("focusMode", ["manual"]);
    choose("whiteBalanceMode", ["manual"]);
  } else {
    choose("exposureMode", ["continuous", "single-shot"]);
    choose(
      "focusMode",
      preset === "运动" ? ["continuous", "single-shot"] : ["single-shot", "continuous"],
    );
    choose("whiteBalanceMode", ["continuous", "single-shot"]);
  }

  if (preset === "风景" && supportsCapability("focusDistance")) {
    const capability = camera.capabilities.focusDistance;
    if (capability?.max !== undefined) requests.push(applyConstraint("focusDistance", capability.max));
  }

  await Promise.all(requests);
  showToast(requests.length ? `已应用“${preset}”设备策略。` : "当前设备没有可调整的预设参数。");
});

$$(".quick-card").forEach((card) => {
  card.addEventListener("click", () => {
    const targets = {
      aperture: "blurSlider",
      brightness: "brightnessSlider",
      whitebalance: "scenePreset",
    };
    const target = document.getElementById(targets[card.dataset.focusParam]);
    target?.focus({ preventScroll: true });
    target?.scrollIntoView({ behavior: "smooth", block: "center" });
  });
});

$$(".stepper").forEach((stepper) => {
  const labels = stepper.dataset.values.split(",");
  const values = stepper.dataset.constraintValues.split(",").map(Number);
  const valueElement = $("strong", stepper);
  const buttons = $$("button", stepper);
  buttons.forEach((button, buttonIndex) => {
    button.addEventListener("click", async () => {
      const previous = Number(stepper.dataset.index);
      const direction = buttonIndex === 0 ? -1 : 1;
      const next = Math.min(labels.length - 1, Math.max(0, previous + direction));
      stepper.dataset.index = String(next);
      valueElement.textContent = labels[next];
      valueElement.classList.remove("is-updating");
      void valueElement.offsetWidth;
      valueElement.classList.add("is-updating");
      buttons[0].disabled = next === 0;
      buttons[1].disabled = next === labels.length - 1;
      await applyConstraint(stepper.dataset.constraint, values[next], () => {
        stepper.dataset.index = String(previous);
        valueElement.textContent = labels[previous];
      });
    });
  });
});

$$("select[data-constraint]").forEach((select) => {
  select.addEventListener("change", () => {
    const name = select.dataset.constraint;
    let value = select.value;
    if (name === "torch") value = value === "true";
    if (name === "focusDistance") value = Number(value);
    applyConstraint(name, value);
  });
});

$("#resetParametersButton").addEventListener("click", async () => {
  $("#blurSlider").value = "2";
  $("#blurSlider").dispatchEvent(new Event("input"));
  $("#brightnessSlider").value = "2";
  $("#brightnessSlider").dispatchEvent(new Event("input"));
  cameraScene.style.filter = "";
  liveVideo.style.filter = "";
  if (
    supportsCapability("exposureMode") &&
    Array.isArray(camera.capabilities.exposureMode) &&
    camera.capabilities.exposureMode.includes("continuous")
  ) {
    await applyConstraint("exposureMode", "continuous");
  }
  if (
    supportsCapability("whiteBalanceMode") &&
    Array.isArray(camera.capabilities.whiteBalanceMode) &&
    camera.capabilities.whiteBalanceMode.includes("continuous")
  ) {
    await applyConstraint("whiteBalanceMode", "continuous");
  }
  showToast("已恢复当前设备可用的自动参数。");
});

commandTrigger.addEventListener("click", () => {
  commandSearch.value = "";
  filterCommands();
  openDialog(commandDialog, commandSearch);
});
commandSearch.addEventListener("input", filterCommands);
commandSearch.addEventListener("keydown", (event) => {
  if (event.key === "ArrowDown") {
    event.preventDefault();
    selectCommand(state.selectedCommandIndex + 1);
  } else if (event.key === "ArrowUp") {
    event.preventDefault();
    selectCommand(state.selectedCommandIndex - 1);
  } else if (event.key === "Enter") {
    event.preventDefault();
    const command = getVisibleCommands()[state.selectedCommandIndex];
    if (command) runCommand(command.dataset.command);
  }
});
$$(".command-item").forEach((item) => {
  item.addEventListener("click", () => runCommand(item.dataset.command));
});

$$(".connection-option").forEach((button) => {
  button.addEventListener("click", () => updateConnectionChoice(button.dataset.connection));
});
connectButton.addEventListener("click", connectSelectedSource);

$$(".dialog-close").forEach((button) => {
  button.addEventListener("click", () => closeDialog(button.closest("dialog")));
});
[commandDialog, connectionDialog].forEach((dialog) => {
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) closeDialog(dialog);
  });
  dialog.addEventListener("close", () => {
    connectionNotice.removeAttribute("data-tone");
  });
});

$("#fullscreenButton").addEventListener("click", async () => {
  const stage = $(".monitor-stage");
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else if (stage.requestFullscreen) await stage.requestFullscreen();
  } catch (error) {
    showToast(`无法进入全屏：${error.message}`);
  }
});

$("#pictureInPictureButton").addEventListener("click", async () => {
  try {
    if (document.pictureInPictureElement) await document.exitPictureInPicture();
    else await monitorVideo.requestPictureInPicture();
  } catch (error) {
    showToast(`无法开启画中画：${error.message}`);
  }
});

$("#cleanFeedSwitch").addEventListener("change", (event) => {
  monitorFrame.classList.toggle("is-clean-feed", event.target.checked);
});
$("#mirrorSwitch").addEventListener("change", (event) => {
  monitorFrame.classList.toggle("is-mirrored", event.target.checked);
});

const requestWakeLock = async () => {
  if (!("wakeLock" in navigator)) {
    $("#wakeLockSwitch").checked = false;
    showToast("当前浏览器不支持保持屏幕唤醒。");
    return;
  }
  try {
    state.wakeLock = await navigator.wakeLock.request("screen");
    state.wakeLock.addEventListener("release", () => {
      state.wakeLock = null;
    });
  } catch (error) {
    $("#wakeLockSwitch").checked = false;
    showToast(`无法保持屏幕唤醒：${error.message}`);
  }
};

$("#wakeLockSwitch").addEventListener("change", async (event) => {
  if (event.target.checked) await requestWakeLock();
  else await state.wakeLock?.release();
});
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && $("#wakeLockSwitch").checked && !state.wakeLock) {
    requestWakeLock();
  }
});

$("#pauseQueueButton").addEventListener("click", (event) => {
  state.queuePaused = !state.queuePaused;
  event.currentTarget.setAttribute("aria-pressed", String(state.queuePaused));
  event.currentTarget.textContent = state.queuePaused ? "继续队列" : "暂停队列";
  showToast(
    state.queuePaused
      ? "已暂停接收新的导入操作；已完成文件不受影响。"
      : "队列已恢复，可继续拍摄和导入。",
  );
  fileInput.disabled = state.queuePaused;
  $("#importFilesButton").disabled = state.queuePaused;
});

camera.addEventListener("settingschange", updateReadouts);
camera.addEventListener("disconnected", () => {
  camera.detachVideo(liveVideo);
  camera.detachVideo(monitorVideo);
  setDisconnectedUi("设备已断开");
  showToast("视频设备已断开。");
});
camera.addEventListener("previewerror", (event) => {
  $("#monitorStatus").textContent = "实时取景正在重试";
  if (event.detail?.error?.code === "DEVICE_DISCONNECTED") {
    setDisconnectedUi("Nikon 相机已断开");
  }
});
liveVideo.addEventListener("loadedmetadata", () => {
  camera.settings = camera.track?.getSettings?.() || camera.settings;
  updateMonitorDetails();
});
navigator.mediaDevices?.addEventListener?.("devicechange", () => populateVideoDevices());

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  state.deferredInstallPrompt = event;
  $("#installButton").hidden = false;
});
$("#installButton").addEventListener("click", async () => {
  if (!state.deferredInstallPrompt) return;
  await state.deferredInstallPrompt.prompt();
  await state.deferredInstallPrompt.userChoice;
  state.deferredInstallPrompt = null;
  $("#installButton").hidden = true;
});
window.addEventListener("appinstalled", () => {
  state.deferredInstallPrompt = null;
  $("#installButton").hidden = true;
  showToast("Nikon Link 已安装。");
});

document.addEventListener("keydown", (event) => {
  const isTyping = ["INPUT", "SELECT", "TEXTAREA"].includes(event.target.tagName);
  if ((event.metaKey || event.ctrlKey) && event.key.toLocaleLowerCase() === "k") {
    event.preventDefault();
    commandSearch.value = "";
    filterCommands();
    openDialog(commandDialog, commandSearch);
    return;
  }
  if (isTyping || commandDialog.open || connectionDialog.open) return;
  if (event.shiftKey && event.key.toLocaleLowerCase() === "m") {
    event.preventDefault();
    setMode(state.mode === "simple" ? "pro" : "simple");
  } else if (event.key.toLocaleLowerCase() === "c") {
    event.preventDefault();
    setView("capture");
    capturePhoto();
  }
});

window.addEventListener("beforeunload", () => {
  clearLibraryUrls();
  state.queueUrls.forEach((url) => URL.revokeObjectURL(url));
  camera.disconnect();
});

if ("serviceWorker" in navigator && location.protocol.startsWith("http")) {
  navigator.serviceWorker.register("./sw.js").catch(() => {
    setRuntimeNotice("离线功能暂时不可用，其他本地功能仍可继续使用。");
  });
}

if (!window.isSecureContext && !camera.nativeSupported) {
  setRuntimeNotice("视频设备连接需要通过 localhost 或 HTTPS 打开。");
}

document.documentElement.dataset.appReady = "true";
setMode(safeRead("nikon-link-mode") || "simple");
setView("capture");
setDisconnectedUi();
if (camera.nativeSupported) {
  $$("[data-native-only]").forEach((element) => {
    element.hidden = false;
  });
  state.connectionMode = "native";
  $("#storageLocation").textContent = "Nikon Link 本地照片库";
  setRuntimeNotice(
    `${window.NikonNativeBridge.platform === "android" ? "Android" : "macOS"} 原生版已就绪，可连接支持的 Nikon EXPEED 7 相机。`,
  );
}
updateConnectionChoice(state.connectionMode);
await storageReady;
await renderLibrary();
refreshStorageEstimate();
