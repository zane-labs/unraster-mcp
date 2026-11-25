#!/usr/bin/env node
// Convert one PNG/JPEG/WebP into an editable .pptx (2 credits, charged only if delivered).
// Usage: UNRASTER_API_KEY=... node convert.mjs slide.png   (Node 18+)
import { readFile, writeFile } from "node:fs/promises";
import { basename, extname } from "node:path";
import { randomUUID } from "node:crypto";
const BASE = (process.env.UNRASTER_API || "https://unraster.ai").replace(/\/+$/, ""); // same variable as scripts/batch.sh
const KEY = process.env.UNRASTER_API_KEY;
const path = process.argv[2];
const die = (msg) => { console.error(msg); process.exit(1); };
if (!KEY || !path) die("usage: UNRASTER_API_KEY=... node convert.mjs <image>  (key: https://unraster.ai/developers/api-keys)");
const api = new URL(BASE);
if (api.protocol !== "https:" && !(api.protocol === "http:" && ["localhost", "127.0.0.1"].includes(api.hostname))) die("UNRASTER_API must be an https URL (http only for localhost).");
const ext = extname(path).toLowerCase();
const type = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp" }[ext];
if (!type) die("Use a PNG, JPEG or WebP image.");
const idem = process.env.UNRASTER_IDEMPOTENCY_KEY || randomUUID(); // reuse the same key to resume
console.error("Idempotency-Key:", idem);
let tid, stage = "submit";
const unsure = (why) => die(`${why}\nTask ID: ${tid || "not received"}. The result is unknown: it may still be processing or already delivered.\n` +
  `Re-run with UNRASTER_IDEMPOTENCY_KEY=${idem} to resume the same task; the same key is never charged twice.`);
// Send the key only to the API host and never follow redirects; ready links on files.unraster.ai need no key.
const call = async (url, init = {}) => {
  const headers = new URL(url).host === api.host ? { Authorization: `Bearer ${KEY}`, ...init.headers } : init.headers;
  const res = await fetch(url, { ...init, headers, redirect: "manual", signal: AbortSignal.timeout(60_000) }).catch((e) =>
    unsure(`${stage === "download" ? "Download failed" : "Network error or timeout"}: ${e.cause?.code || e.name}`));
  if (!res.ok) {
    const e = (await res.json().catch(() => ({}))).error, what = `HTTP ${res.status}${e ? ` ${e.code}: ${e.message}` : ""}`;
    if (stage === "submit" && res.status === 409) die(`Rejected: ${what}. This Idempotency-Key was already used for a different request; the earlier task, if any, is unaffected. Unset UNRASTER_IDEMPOTENCY_KEY to start a new one.`);
    if (stage === "submit" && res.status >= 400 && res.status < 500 && res.status !== 429) die(`Rejected: ${what} (nothing was charged).`);
    if (res.status === 429 && stage === "poll") return res; // caller waits and retries
    unsure(stage === "download" ? `Conversion finished but the download failed: ${what}` : `Request error: ${what}`);
  }
  return res;
};
try {
const form = new FormData();
form.set("outputs", "pptx");
form.set("file", new Blob([await readFile(path)], { type }), `image${ext}`);
let task = await (await call(`${BASE}/v1/conversions`, { method: "POST", headers: { "Idempotency-Key": idem }, body: form })).json();
tid = task.id; stage = "poll";
console.error("Task ID:", tid);
for (const end = Date.now() + 600_000; ["queued", "processing"].includes(task.status); ) {
  if (Date.now() > end) unsure("Still processing after 10 minutes.");
  await new Promise((r) => setTimeout(r, 3000));
  const res = await call(`${BASE}/v1/conversions/${tid}`);
  if (res.status === 429) { await new Promise((r) => setTimeout(r, (Number(res.headers.get("retry-after")) || 5) * 1000)); continue; }
  task = await res.json();
}
const out = (task.outputs || []).find((o) => o.format === "pptx" && o.status === "ready");
if (!out) die(`No PowerPoint was delivered (status=${task.status}). Undelivered files are not charged.`);
stage = "download";
const dest = basename(path, extname(path)) + ".pptx";
await writeFile(dest, Buffer.from(await (await call(new URL(out.url, BASE + "/").href)).arrayBuffer()));
console.log("Saved", dest);
} catch (e) { unsure(`${stage === "download" ? "Download failed" : "Network error or unreadable response"}: ${e.cause?.code || e.name}`); }
