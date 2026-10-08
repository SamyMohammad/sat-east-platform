// Browser run of the checkout flow against a running server (default http://localhost:8790).
//   node spikes/paymob/e2e/web_e2e.mjs [mock|live]
// mock: drives the mock Paymob page (decline once, then pay) and expects "Enrolled".
// live: opens the real Paymob page and waits up to 5 min for a human to pay with a test card.
import { chromium } from 'playwright';

const mode = process.argv[2] ?? 'mock';
const APP = process.env.APP ?? 'http://localhost:8790';
const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined, headless: mode === 'mock' });
const page = await browser.newPage();
const t0 = Date.now();
const note = (s) => console.log(`${((Date.now() - t0) / 1000).toFixed(1)}s ${s}`);
page.on('framenavigated', (f) => f === page.mainFrame() && note(`at ${f.url().replace(/hmac=[0-9a-f]+/, 'hmac=…').slice(0, 140)}`));

let result = 'FAIL';
try {
  await page.goto(APP);
  await page.fill('#coupon', 'SPIKE10');
  await page.click('#pay');
  if (mode === 'mock') {
    await page.waitForSelector('#decline');
    note(`mock checkout shows: ${await page.textContent('p')}`);
    await page.click('#decline');
    await page.waitForSelector('#pay');
    note('declined once, retrying on the same order');
    await page.click('#pay');
  }
  await page.waitForFunction(() => document.getElementById('status')?.textContent.startsWith('Enrolled'), null,
    { timeout: mode === 'mock' ? 15_000 : 300_000 });
  note(`status: ${await page.textContent('#status')}`);
  result = 'PASS';
} catch (e) {
  note(`ERROR ${e.message.split('\n')[0]}`);
  note(`status: ${await page.textContent('#status').catch(() => '-')}`);
} finally {
  console.log(`RESULT ${mode}: ${result}`);
  await browser.close();
}
