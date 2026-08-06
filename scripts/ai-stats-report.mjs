#!/usr/bin/env node
// ZENCHE AI 激活统计报表（一次性脚本，直接读取 data/devices.json 输出与
// GET /v1/admin/stats 同口径的统计）。用法：
//   node scripts/ai-stats-report.mjs [path/to/devices.json] [maxUsage=100]
// 默认路径 data/devices.json（相对仓库根）；maxUsage 对齐 ZENCHE_AI_MAX_USAGE。
import fs from "node:fs";
import path from "node:path";

const dbFile = process.argv[2] || path.join(process.cwd(), "data", "devices.json");
const maxUsage = Number(process.argv[3] || 100);
if (!fs.existsSync(dbFile)) {
  console.error(`devices.json 不存在: ${dbFile}`);
  process.exit(1);
}

// resolveMigrationTail：与 ai-server/app.mjs 导出的实现同逻辑。
function resolveMigrationTail(devices, deviceId) {
  let current = deviceId;
  const seen = new Set();
  while (devices[current] && devices[current].migrated_to && !seen.has(current)) {
    seen.add(current);
    current = devices[current].migrated_to;
  }
  return current;
}

const devices = JSON.parse(fs.readFileSync(dbFile, "utf8"));
const dayMs = 24 * 60 * 60 * 1000;
const now = Date.now();
const tailSeen = new Map();
const remaining = new Map();
const tails = new Set();
for (const [deviceId, record] of Object.entries(devices)) {
  if (!record || typeof record !== "object") continue;
  const tail = resolveMigrationTail(devices, deviceId);
  tails.add(tail);
  const seen = Number(record.last_seen) || 0;
  if (seen > (tailSeen.get(tail) || 0)) tailSeen.set(tail, seen);
  const rem = Math.max(0, maxUsage - (Number(record.used) || 0));
  const current = remaining.get(tail);
  if (current === undefined || rem < current) remaining.set(tail, rem);
}
const active24h = [...tailSeen.values()].filter((ts) => now - ts <= dayMs).length;
const active7d = [...tailSeen.values()].filter((ts) => now - ts <= 7 * dayMs).length;
const buckets = { zero: 0, low1to10: 0, mid11to50: 0, high51to99: 0, full100: 0 };
for (const rem of remaining.values()) {
  if (rem <= 0) buckets.zero += 1;
  else if (rem <= 10) buckets.low1to10 += 1;
  else if (rem <= 50) buckets.mid11to50 += 1;
  else if (rem < maxUsage) buckets.high51to99 += 1;
  else buckets.full100 += 1;
}
console.log(JSON.stringify({
  dbFile,
  maxUsage,
  totalDevices: tails.size,
  active24h,
  active7d,
  remainingDistribution: buckets,
  generated_at: new Date(now).toISOString(),
}, null, 2));
