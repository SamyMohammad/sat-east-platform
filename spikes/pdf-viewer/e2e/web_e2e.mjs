// Web check of the PDF spike (Chrome via Playwright).
//   node spikes/pdf-viewer/e2e/web_e2e.mjs <memory|uri> [outDir]
// Needs: spike server on :8792 started with a short TOKEN_TTL_S (e.g. 20), player build on :8081.
// Opens the notes, waits past the URL expiry (jumpAfter=30), jumps to the last page, and checks
// that the last page still renders. Logs every request to the server and the PDFium WASM fetch.
import { chromium } from 'playwright';

const [mode = 'memory', outDir = '.'] = process.argv.slice(2);
const APP = process.env.APP ?? 'http://localhost:8081';
const SERVER = process.env.SERVER ?? 'http://localhost:8792';
const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const t0 = Date.now();
const log = [];
const note = (s) => log.push(`${((Date.now() - t0) / 1000).toFixed(1)}s ${s}`);
let pdfFetches = 0;
let errors = 0;
let lastPageShown = false;
page.on('console', (m) => {
  const t = m.text();
  if (!t.includes('[pdf-spike]')) return;
  note(`console ${t}`);
  if (t.includes('viewer error') || t.includes('open failed')) errors++;
  if (/page 40$/.test(t)) lastPageShown = true;
});
page.on('response', async (r) => {
  const u = new URL(r.url());
  if (u.pathname.endsWith('pdfium.wasm')) {
    const len = (await r.body().catch(() => Buffer.alloc(0))).length;
    note(`pdfium.wasm ${r.status()} ${(len / 1e6).toFixed(1)} MB`);
  }
  if (u.port !== new URL(SERVER).port) return;
  const range = r.request().headers()['range'];
  if (u.pathname.startsWith('/f/')) pdfFetches++;
  note(`${r.request().method()} ${u.pathname.replace(/\/f\/[^/]+\//, '/f/<token>/')}${range ? ` [${range}]` : ''} → ${r.status()}`);
});

let result = 'FAIL';
try {
  await page.goto(`${APP}/?mode=${mode}&jumpAfter=30&server=${encodeURIComponent(SERVER)}&user=${encodeURIComponent('سارة أحمد')}`);
  await page.waitForTimeout(8_000);
  await page.screenshot({ path: `${outDir}/pdf-${mode}-first.png` });
  await page.waitForTimeout(30_000); // URL expired (TTL 20 s), then the app jumps to page 40
  await page.screenshot({ path: `${outDir}/pdf-${mode}-last.png` });
  note(`pdf fetches: ${pdfFetches}, viewer errors: ${errors}, reached last page: ${lastPageShown}`);
  result = errors === 0 && lastPageShown ? 'PASS' : 'FAIL';
} catch (e) {
  note(`ERROR ${e.message.split('\n')[0]}`);
} finally {
  console.log(log.join('\n'));
  console.log(`RESULT ${mode}: ${result}`);
  await browser.close();
}
