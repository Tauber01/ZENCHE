const NIKON_VENDOR_ID = 0x04b0;

const makeError = (code, message, cause) => {
  const error = new Error(message, cause ? { cause } : undefined);
  error.code = code;
  return error;
};

const canvasToBlob = (canvas, type = "image/jpeg", quality = 0.94) =>
  new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(makeError("CAPTURE_FAILED", "浏览器未能生成照片文件。"));
      },
      type,
      quality,
    );
  });

const dataUrlToBlob = (dataUrl) => {
  const [header, encoded] = String(dataUrl || "").split(",", 2);
  if (!encoded) throw makeError("INVALID_IMAGE", "原生相机没有返回有效图像。");
  const type = header.match(/^data:([^;]+)/)?.[1] || "image/jpeg";
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return new Blob([bytes], { type });
};

export class CameraService extends EventTarget {
  constructor() {
    super();
    this.stream = null;
    this.track = null;
    this.mode = "disconnected";
    this.device = null;
    this.capabilities = {};
    this.settings = {};
    this.previewTimer = null;
    this.previewBusy = false;
  }

  get mediaSupported() {
    return Boolean(navigator.mediaDevices?.getUserMedia);
  }

  get webUsbSupported() {
    return Boolean(navigator.usb?.requestDevice);
  }

  get nativeSupported() {
    return Boolean(window.NikonNativeBridge?.available);
  }

  get connected() {
    return (
      (this.mode === "media" && this.track?.readyState === "live") ||
      (this.mode === "native" && Boolean(this.device))
    );
  }

  async connectNative() {
    if (!this.nativeSupported) {
      throw makeError("NATIVE_UNAVAILABLE", "请使用 帧澈 ZENCHE 原生安装版连接 EXPEED 7 相机。");
    }
    await this.disconnect();
    const result = await window.NikonNativeBridge.call("connect", {}, 45_000);
    this.mode = "native";
    this.device = result.device || {
      id: "nikon-expeed7",
      label: "Nikon EXPEED 7 相机",
    };
    this.capabilities = result.capabilities || {};
    this.settings = result.settings || {};
    this.dispatchEvent(
      new CustomEvent("connected", {
        detail: {
          mode: this.mode,
          device: this.device,
          capabilities: this.capabilities,
          settings: this.settings,
        },
      }),
    );
    return result;
  }

  async startNativePreview(onFrame) {
    if (this.mode !== "native") return;
    await window.NikonNativeBridge.call("startLiveView");
    this.stopNativePreview(false);
    const poll = async () => {
      if (this.mode !== "native" || this.previewBusy) return;
      this.previewBusy = true;
      try {
        const result = await window.NikonNativeBridge.call("getLiveViewFrame", {}, 12_000);
        if (result?.dataUrl) onFrame?.(result.dataUrl, result);
      } catch (error) {
        this.dispatchEvent(new CustomEvent("previewerror", { detail: { error } }));
      } finally {
        this.previewBusy = false;
      }
    };
    await poll();
    this.previewTimer = window.setInterval(poll, 350);
  }

  stopNativePreview(endSession = true) {
    if (this.previewTimer) window.clearInterval(this.previewTimer);
    this.previewTimer = null;
    if (endSession && this.mode === "native") {
      window.NikonNativeBridge.call("stopLiveView").catch(() => {});
    }
  }

  async listVideoDevices() {
    if (!navigator.mediaDevices?.enumerateDevices) return [];
    const devices = await navigator.mediaDevices.enumerateDevices();
    return devices.filter((device) => device.kind === "videoinput");
  }

  async connectMedia(deviceId = "") {
    if (!this.mediaSupported) {
      throw makeError(
        "MEDIA_UNSUPPORTED",
        "当前浏览器不支持视频设备访问。请使用最新版 Safari、Chrome 或 Edge。",
      );
    }

    this.disconnect();

    const video = {
      width: { ideal: 3840 },
      height: { ideal: 2160 },
      frameRate: { ideal: 30, max: 60 },
    };

    if (deviceId) video.deviceId = { exact: deviceId };

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: false, video });
    } catch (error) {
      if (error.name === "NotAllowedError") {
        throw makeError("PERMISSION_DENIED", "未获得相机权限。请在浏览器设置中允许访问相机。", error);
      }
      if (error.name === "NotFoundError" || error.name === "OverconstrainedError") {
        throw makeError("DEVICE_NOT_FOUND", "没有找到可用的视频设备，或所选设备已断开。", error);
      }
      throw makeError("CONNECT_FAILED", `无法连接视频设备：${error.message}`, error);
    }

    this.track = this.stream.getVideoTracks()[0];
    this.mode = "media";
    this.device = {
      id: this.track.getSettings?.().deviceId || deviceId,
      label: this.track.label || "系统视频设备",
    };
    this.capabilities = this.track.getCapabilities?.() || {};
    this.settings = this.track.getSettings?.() || {};

    const connectedTrack = this.track;
    this.track.addEventListener(
      "ended",
      () => {
        if (this.track !== connectedTrack) return;
        this.mode = "disconnected";
        this.dispatchEvent(new CustomEvent("disconnected", { detail: { reason: "device-ended" } }));
      },
      { once: true },
    );

    this.dispatchEvent(
      new CustomEvent("connected", {
        detail: {
          mode: this.mode,
          device: this.device,
          capabilities: this.capabilities,
          settings: this.settings,
        },
      }),
    );

    return {
      stream: this.stream,
      track: this.track,
      device: this.device,
      capabilities: this.capabilities,
      settings: this.settings,
    };
  }

  connectDemo() {
    this.disconnect();
    this.mode = "demo";
    this.device = { id: "demo", label: "内置演示场景" };
    this.capabilities = {};
    this.settings = { width: 1600, height: 1000, frameRate: 0 };
    this.dispatchEvent(
      new CustomEvent("connected", {
        detail: {
          mode: this.mode,
          device: this.device,
          capabilities: this.capabilities,
          settings: this.settings,
        },
      }),
    );
    return {
      stream: null,
      track: null,
      device: this.device,
      capabilities: this.capabilities,
      settings: this.settings,
    };
  }

  async detectNikonUsb() {
    if (!this.webUsbSupported) {
      throw makeError(
        "WEBUSB_UNSUPPORTED",
        "当前浏览器不支持 WebUSB。可改用系统视频设备，或在原生版本中接入尼康 SDK。",
      );
    }

    try {
      const device = await navigator.usb.requestDevice({
        filters: [{ vendorId: NIKON_VENDOR_ID }],
      });
      return {
        productName: device.productName || "Nikon USB Camera",
        manufacturerName: device.manufacturerName || "Nikon",
        serialNumber: device.serialNumber || "",
        vendorId: device.vendorId,
        productId: device.productId,
      };
    } catch (error) {
      if (error.name === "NotFoundError") {
        throw makeError("USB_CANCELLED", "没有选择尼康 USB 设备。", error);
      }
      throw makeError("USB_DETECTION_FAILED", `无法检测尼康 USB 设备：${error.message}`, error);
    }
  }

  async attachVideo(video) {
    if (!video) return;
    video.srcObject = this.stream;
    video.hidden = !this.stream;
    if (this.stream) {
      await video.play();
    }
  }

  detachVideo(video) {
    if (!video) return;
    video.pause();
    video.srcObject = null;
    video.hidden = true;
  }

  async applyConstraint(name, value) {
    if (this.mode === "native") {
      try {
        const result = await window.NikonNativeBridge.call("setParameter", { name, value });
        this.settings = { ...this.settings, ...(result.settings || {}), [name]: result.value ?? value };
        this.dispatchEvent(
          new CustomEvent("settingschange", {
            detail: { name, value: this.settings[name], settings: this.settings },
          }),
        );
        return this.settings[name];
      } catch (error) {
        throw makeError("CONSTRAINT_FAILED", error.message, error);
      }
    }
    if (!this.track || this.track.readyState !== "live") {
      throw makeError("NOT_CONNECTED", "请先连接支持参数控制的视频设备。");
    }

    const capability = this.capabilities[name];
    if (capability === undefined) {
      throw makeError("UNSUPPORTED_CONSTRAINT", `当前设备不支持“${name}”控制。`);
    }

    let normalized = value;
    if (typeof capability === "object" && !Array.isArray(capability) && "min" in capability) {
      normalized = Math.min(capability.max, Math.max(capability.min, Number(value)));
    } else if (typeof capability === "boolean") {
      normalized = value === true || value === "true";
    } else if (Array.isArray(capability) && !capability.includes(value)) {
      throw makeError("UNSUPPORTED_VALUE", `当前设备不支持“${value}”。`);
    }

    try {
      await this.track.applyConstraints({ advanced: [{ [name]: normalized }] });
      this.settings = this.track.getSettings?.() || this.settings;
      this.dispatchEvent(
        new CustomEvent("settingschange", {
          detail: { name, value: this.settings[name] ?? normalized, settings: this.settings },
        }),
      );
      return this.settings[name] ?? normalized;
    } catch (error) {
      throw makeError("CONSTRAINT_FAILED", `设备拒绝了该参数：${error.message}`, error);
    }
  }

  async capture(video) {
    if (this.mode === "demo") return this.#captureDemo();
    if (this.mode === "native") {
      const result = await window.NikonNativeBridge.call("capture", {}, 60_000);
      return dataUrlToBlob(result.dataUrl);
    }
    if (!this.track || this.track.readyState !== "live") {
      throw makeError("NOT_CONNECTED", "请先连接视频设备再拍摄。");
    }

    if ("ImageCapture" in window) {
      try {
        const imageCapture = new ImageCapture(this.track);
        return await imageCapture.takePhoto();
      } catch {
        // Some UVC drivers expose ImageCapture but only support frame grabbing.
      }
    }

    if (!video?.videoWidth || !video?.videoHeight) {
      throw makeError("VIDEO_NOT_READY", "实时画面尚未准备好，请稍后再拍。");
    }

    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const context = canvas.getContext("2d", { alpha: false });
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    return canvasToBlob(canvas);
  }

  async #captureDemo() {
    const canvas = document.createElement("canvas");
    canvas.width = 1600;
    canvas.height = 1000;
    const context = canvas.getContext("2d", { alpha: false });
    const styles = getComputedStyle(document.documentElement);
    const color = (token) => styles.getPropertyValue(token).trim();

    const wall = context.createLinearGradient(0, 0, canvas.width, canvas.height * 0.65);
    wall.addColorStop(0, color("--color-scene-wall-a"));
    wall.addColorStop(1, color("--color-scene-wall-b"));
    context.fillStyle = wall;
    context.fillRect(0, 0, canvas.width, canvas.height * 0.65);

    const table = context.createLinearGradient(0, canvas.height * 0.65, canvas.width, canvas.height);
    table.addColorStop(0, color("--color-scene-table-a"));
    table.addColorStop(1, color("--color-scene-table-b"));
    context.fillStyle = table;
    context.fillRect(0, canvas.height * 0.65, canvas.width, canvas.height * 0.35);

    context.fillStyle = color("--color-scene-object");
    context.roundRect(700, 320, 225, 410, 24);
    context.fill();
    context.fillRect(755, 250, 115, 90);
    context.fillStyle = color("--color-ink");
    context.roundRect(740, 225, 145, 38, 10);
    context.fill();

    context.fillStyle = color("--color-paper-2");
    context.fillRect(730, 485, 165, 115);
    context.fillStyle = color("--color-ink");
    context.font = "32px monospace";
    context.textAlign = "center";
    context.fillText("N•01", 812, 555);

    context.fillStyle = color("--color-scene-fruit");
    context.beginPath();
    context.arc(1040, 640, 72, 0, Math.PI * 2);
    context.fill();

    return canvasToBlob(canvas);
  }

  async disconnect() {
    const wasNative = this.mode === "native";
    this.stopNativePreview(false);
    const previousStream = this.stream;
    this.stream = null;
    this.track = null;
    this.mode = "disconnected";
    this.device = null;
    this.capabilities = {};
    this.settings = {};
    previousStream?.getTracks().forEach((track) => track.stop());
    if (wasNative && window.NikonNativeBridge?.available) {
      await window.NikonNativeBridge.call("disconnect").catch(() => {});
    }
  }
}
