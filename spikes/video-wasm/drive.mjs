// Headless driver: node drive.mjs media/src_120s.mp4
// Samples summed private memory of all Chrome processes of this run via PowerShell.
import puppeteer from 'puppeteer-core';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';

const file = path.resolve(process.argv[2]);
const udd = fs.mkdtempSync(path.join(os.tmpdir(), 'spike-chrome-'));
const browser = await puppeteer.launch({
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: true, userDataDir: udd, protocolTimeout: 0,
  args: ['--enable-precise-memory-info'],
});
const page = await browser.newPage();
page.on('pageerror', (e) => console.log('PAGEERR', e.message));
page.on('console', (m) => { if (m.type() === 'error' || m.text().startsWith('progress')) console.log('CONSOLE', m.text()); });
await page.goto('http://localhost:8099/');
console.log('crossOriginIsolated =', await page.evaluate(() => crossOriginIsolated), 'SAB =', await page.evaluate(() => typeof SharedArrayBuffer));

const ps = `(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*${path.basename(udd)}*' } | ForEach-Object { (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue).PrivateMemorySize64 } | Measure-Object -Sum).Sum`;
let peak = 0, stop = false;
const poll = (async () => {
  while (!stop) {
    try { peak = Math.max(peak, Number(execFileSync('powershell', ['-NoProfile', '-Command', ps]).toString().trim() || 0)); } catch { /* ignore */ }
    await new Promise((r) => setTimeout(r, 3000));
  }
})();

const input = await page.$('#f');
await input.uploadFile(file);
const t = Date.now();
const result = await page.evaluate(() => runSpike(document.getElementById('f').files[0]));
stop = true; await poll;
console.log(JSON.stringify(result));
console.log('peak Chrome private memory MB (all procs, 3s sampling):', Math.round(peak / 1048576));
const ver = await page.evaluate(() => verifyOutput());
console.log('verify', JSON.stringify(ver));
console.log('wall s', (Date.now() - t) / 1000);
const out = path.resolve('out/wasm'); fs.mkdirSync(out, { recursive: true });
await page.evaluate(async () => { for (const n of ['master.m3u8', '540p.m3u8']) await fetch('/save/' + n, { method: 'POST', body: getOutText(n) }); });
if (process.argv[3] === 'save') { await page.evaluate(() => saveAll()); console.log('saved to', out, 'key', await page.evaluate(() => getKeyHex())); }
await browser.close();
