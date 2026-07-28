const DATABASE_NAME = "nikon-link-library";
const DATABASE_VERSION = 1;
const STORE_NAME = "photos";

const createId = () =>
  globalThis.crypto?.randomUUID?.() ||
  `photo-${Date.now()}-${Math.random().toString(16).slice(2)}`;

const requestToPromise = (request) =>
  new Promise((resolve, reject) => {
    request.addEventListener("success", () => resolve(request.result), { once: true });
    request.addEventListener("error", () => reject(request.error), { once: true });
  });

export class PhotoStorage {
  constructor() {
    this.database = null;
    this.memory = new Map();
    this.usingMemoryFallback = false;
  }

  async init(timeoutMs = 1500) {
    if (!("indexedDB" in globalThis)) {
      this.usingMemoryFallback = true;
      return this;
    }

    try {
      const request = indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
      this.database = await new Promise((resolve, reject) => {
        let settled = false;
        const finish = (callback, value) => {
          if (settled) return;
          settled = true;
          window.clearTimeout(timer);
          callback(value);
        };
        const timer = window.setTimeout(() => {
          finish(reject, new Error("本地照片库初始化超时。"));
        }, timeoutMs);

        request.addEventListener("upgradeneeded", () => {
          const database = request.result;
          if (!database.objectStoreNames.contains(STORE_NAME)) {
            const store = database.createObjectStore(STORE_NAME, { keyPath: "id" });
            store.createIndex("capturedAt", "capturedAt");
          }
        });
        request.addEventListener("success", () => {
          if (settled) {
            request.result.close();
            return;
          }
          finish(resolve, request.result);
        });
        request.addEventListener("error", () => finish(reject, request.error));
      });
    } catch {
      this.usingMemoryFallback = true;
    }
    return this;
  }

  async saveBlob(blob, options = {}) {
    const capturedAt = options.capturedAt || new Date().toISOString();
    const extension = blob.type === "image/png" ? "png" : "jpg";
    const record = {
      id: options.id || createId(),
      name: options.name || `NIKON_${capturedAt.replace(/\D/g, "").slice(0, 14)}.${extension}`,
      blob,
      type: blob.type || "application/octet-stream",
      size: blob.size,
      capturedAt,
      source: options.source || "camera",
      metadata: options.metadata || {},
    };
    await this.put(record);
    return record;
  }

  async importFiles(files) {
    const records = [];
    for (const file of files) {
      if (!file.size) continue;
      const record = await this.saveBlob(file, {
        name: file.name,
        capturedAt: new Date(file.lastModified || Date.now()).toISOString(),
        source: "import",
        metadata: { lastModified: file.lastModified },
      });
      records.push(record);
    }
    return records;
  }

  async put(record) {
    if (this.usingMemoryFallback || !this.database) {
      this.memory.set(record.id, record);
      return record;
    }
    const transaction = this.database.transaction(STORE_NAME, "readwrite");
    await requestToPromise(transaction.objectStore(STORE_NAME).put(record));
    return record;
  }

  async putMany(records) {
    for (const record of records) await this.put(record);
  }

  async list() {
    let records;
    if (this.usingMemoryFallback || !this.database) {
      records = [...this.memory.values()];
    } else {
      const transaction = this.database.transaction(STORE_NAME, "readonly");
      records = await requestToPromise(transaction.objectStore(STORE_NAME).getAll());
    }
    return records.sort((a, b) => b.capturedAt.localeCompare(a.capturedAt));
  }

  async remove(ids) {
    if (this.usingMemoryFallback || !this.database) {
      ids.forEach((id) => this.memory.delete(id));
      return;
    }
    const transaction = this.database.transaction(STORE_NAME, "readwrite");
    const store = transaction.objectStore(STORE_NAME);
    await Promise.all(ids.map((id) => requestToPromise(store.delete(id))));
  }

  async get(id) {
    if (this.usingMemoryFallback || !this.database) return this.memory.get(id);
    const transaction = this.database.transaction(STORE_NAME, "readonly");
    return requestToPromise(transaction.objectStore(STORE_NAME).get(id));
  }
}
