const pending = new Map();
let sequence = 0;

const parseResponse = (value) => {
  if (typeof value === "string") {
    try {
      return JSON.parse(value);
    } catch {
      return { ok: false, error: value };
    }
  }
  return value || {};
};

const send = (message) => {
  const macHandler = window.webkit?.messageHandlers?.nikonNative;
  if (macHandler?.postMessage) {
    macHandler.postMessage(message);
    return true;
  }
  if (window.NikonAndroid?.postMessage) {
    window.NikonAndroid.postMessage(JSON.stringify(message));
    return true;
  }
  return false;
};

const call = (method, params = {}, timeout = 30_000) =>
  new Promise((resolve, reject) => {
    const id = `nl-${Date.now()}-${++sequence}`;
    const timer = window.setTimeout(() => {
      pending.delete(id);
      reject(new Error(`原生相机操作超时：${method}`));
    }, timeout);

    pending.set(id, { resolve, reject, timer });
    if (!send({ id, method, params })) {
      window.clearTimeout(timer);
      pending.delete(id);
      reject(new Error("当前不是 Nikon Link 原生安装版。"));
    }
  });

window.NikonNativeBridge = {
  get available() {
    return Boolean(
      window.webkit?.messageHandlers?.nikonNative?.postMessage ||
        window.NikonAndroid?.postMessage,
    );
  },
  get platform() {
    if (window.NikonAndroid?.postMessage) return "android";
    if (window.webkit?.messageHandlers?.nikonNative?.postMessage) return "macos";
    return "web";
  },
  call,
  _resolve(id, rawResponse) {
    const item = pending.get(id);
    if (!item) return;
    pending.delete(id);
    window.clearTimeout(item.timer);
    const response = parseResponse(rawResponse);
    if (response.ok === false) {
      const error = new Error(response.error || "原生相机操作失败。");
      error.code = response.code || "NATIVE_ERROR";
      item.reject(error);
      return;
    }
    item.resolve(response.result ?? response);
  },
};

window.dispatchEvent(
  new CustomEvent("nikon-native-ready", {
    detail: {
      available: window.NikonNativeBridge.available,
      platform: window.NikonNativeBridge.platform,
    },
  }),
);
