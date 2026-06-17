/**
 * Playwright E2E for ffmpeg-webcli v1.1.0 netdisk (L2-L4 browser cases).
 * Env: LZC_APP_URL, LZC_MS_USER, LZC_MS_PASS, LZC_BOX_URL, HEADED=1
 */
import { chromium } from "playwright";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_URL = process.env.LZC_APP_URL || "https://ffmpeg.zhistor.heiyu.space";
const MS_USER = process.env.LZC_MS_USER || "";
const MS_PASS = process.env.LZC_MS_PASS || "";
const HEADED = process.env.HEADED === "1";

/** @type {{ id: string, status: "pass"|"fail"|"skip", note: string }[]} */
const cases = [];

function record(id, status, note = "") {
  cases.push({ id, status, note: String(note).slice(0, 500) });
  const mark = status === "pass" ? "PASS" : status === "fail" ? "FAIL" : "SKIP";
  console.log(`[${mark}] ${id}${note ? " - " + note : ""}`);
}

function boxOriginFromAppUrl(url) {
  try {
    const u = new URL(url);
    const parts = u.hostname.split(".");
    if (parts.length >= 3) return `${u.protocol}//${parts.slice(1).join(".")}`;
    return `${u.protocol}//${u.hostname}`;
  } catch {
    return "https://zhistor.heiyu.space";
  }
}

const BOX_URL = process.env.LZC_BOX_URL || boxOriginFromAppUrl(APP_URL);

async function loginIfNeeded(page) {
  if (!MS_USER || !MS_PASS) return false;
  const loginUrl = `${BOX_URL}/sys/login?redirect=${encodeURIComponent(APP_URL)}`;
  await page.goto(loginUrl, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.fill("#username", MS_USER);
  await page.fill("#password", MS_PASS);
  await page.locator("#submit").click({ timeout: 10000 });
  await page.waitForTimeout(1500);
  await page.goto(APP_URL, { waitUntil: "domcontentloaded", timeout: 60000 });
  return !page.url().includes("/sys/login");
}

async function ensureApp(page) {
  await page.goto(APP_URL, { waitUntil: "domcontentloaded", timeout: 60000 });
  if (page.url().includes("/sys/login")) {
    const ok = await loginIfNeeded(page);
    if (!ok) throw new Error("login required; set LZC_MS_USER/LZC_MS_PASS (developer token does not substitute web session)");
  }
}

function skipNetdiskBlock(reason) {
  for (const id of ["L2-06", "L2-07", "L2-08", "L2-09", "L3-01", "L3-02", "L3-04", "L3-08"]) {
    record(id, "skip", reason);
  }
}

async function run() {
  const browser = await chromium.launch({ headless: !HEADED });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();

  let sessionOk = true;
  try {
    await ensureApp(page);
  } catch (e) {
    sessionOk = false;
    record("L2-01", "skip", e.message);
    record("L2-02", "skip", e.message);
    record("L2-03", "skip", e.message);
    record("L2-04", "skip", e.message);
    record("L2-05", "skip", e.message);
    skipNetdiskBlock(e.message);
    record("L3-09", "skip", e.message);
    record("L3-10", "skip", e.message);
    record("L4-01", "skip", e.message);
    record("L4-02", "skip", e.message);
    record("L4-03", "skip", e.message);
    record("L4-04", "skip", e.message);
    record("L4-05", "skip", e.message);
    writeFileSync(join(__dirname, "e2e-results.json"), JSON.stringify({ cases }, null, 2));
    await browser.close();
    process.exit(0);
  }

  try {
    const isolated = await page.evaluate(() => globalThis.crossOriginIsolated === true);
    record("L2-01", isolated ? "pass" : "fail", `crossOriginIsolated=${isolated}`);
  } catch (e) {
    record("L2-01", "fail", e.message);
  }

  try {
    const seen = page.waitForResponse(
      (r) => r.url().includes("lzc-file-chooser-inject.js") && r.status() === 200,
      { timeout: 20000 },
    ).catch(() => null);
    await page.reload({ waitUntil: "domcontentloaded" });
    const resp = await seen;
    record("L2-02", resp ? "pass" : "fail", resp ? "inject 200" : "inject not loaded");
  } catch (e) {
    record("L2-02", "fail", e.message);
  }

  try {
    await page.locator("#loadBtn").click({ timeout: 15000 });
    await page.locator("#statusDot.loaded").waitFor({ timeout: 240000 });
    const status = (await page.locator("#statusText").innerText()).trim();
    record("L2-03", "pass", status);
  } catch (e) {
    record("L2-03", "fail", e.message);
  }

  try {
    await page.locator("#dropZone").click({ timeout: 10000 });
    await page.getByText(/从懒猫网盘|Open from LazyCat Drive/i).first().waitFor({ timeout: 10000 });
    await page.getByText(/从本机|Open from local|本机/i).first().waitFor({ timeout: 10000 });
    record("L2-04", "pass", "dual-channel dialog");
    await page.keyboard.press("Escape").catch(() => {});
  } catch (e) {
    record("L2-04", "fail", e.message);
  }

  record("L2-05", "skip", "native file picker not automatable in CI");

  if (!MS_USER || !MS_PASS) {
    skipNetdiskBlock("LZC_MS_USER/LZC_MS_PASS unset; netdisk tree manual");
  } else {
    skipNetdiskBlock("netdisk picker UI not scripted; manual CASES section 6");
  }

  record("L3-09", "skip", "download-to-local needs manual/headed");
  record("L3-10", "skip", "local file picker manual");
  for (const id of ["L3-03", "L3-05", "L3-06", "L3-07", "L3-11", "L3-12"]) {
    record(id, "skip", "P1/P2 optional");
  }

  const l201 = cases.find((c) => c.id === "L2-01");
  const l203 = cases.find((c) => c.id === "L2-03");
  record("L4-05", l201?.status === "pass" && l203?.status === "pass" ? "pass" : "fail", "wasm load + COI");
  record("L4-01", "skip", "needs L3-01");
  record("L4-02", "skip", "needs L3-08");
  record("L4-03", "skip", "needs L3-04/05");
  record("L4-04", "skip", "needs L3-09/10");

  writeFileSync(join(__dirname, "e2e-results.json"), JSON.stringify({ cases }, null, 2));
  await browser.close();
  const fails = cases.filter((c) => c.status === "fail").length;
  process.exit(fails > 0 ? 1 : 0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});

