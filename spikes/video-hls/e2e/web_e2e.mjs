// Web end-to-end check of the spike (Chromium via Playwright).
//   node spikes/video-hls/e2e/web_e2e.mjs <scenario> [outDir]
// Needs: spike server on :8787 (or SERVER env), player build served on :8080 (or APP env).
// Scenarios:
//   play      – plays ≥ 10 s, key fetched once with a token, segments encrypted on the wire
//   recover   – after 6 s every segment request fails (expired presigned URLs after a long pause);
//               the app must call video-otp again and resume near the same position
//   expire    – token expires mid-play, then the player switches to 480p (as ABR would):
//               records what the player does when the 480p playlist/key need the expired token
import { chromium } from 'playwright';

const [scenario = 'play', outDir = '.'] = process.argv.slice(2);
const SERVER = process.env.SERVER ?? 'http://localhost:8787';
const APP = process.env.APP ?? 'http://localhost:8080';

const browser = await chromium.launch({
  executablePath: process.env.CHROME ?? undefined,
  args: ['--autoplay-policy=no-user-gesture-required'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const log = [];
// Wrap the global Hls class so hls.js errors show up in the log.
await page.addInitScript(() => {
  let wrapped;
  Object.defineProperty(window, 'Hls', {
    configurable: true,
    get: () => wrapped,
    set: (Orig) => {
      wrapped = class extends Orig {
        constructor(cfg) {
          super(cfg);
          window.__hls = this;
          this.on('hlsError', (_, d) => console.log(`[hls-spike] hlsError ${d.type}/${d.details} fatal=${d.fatal}`));
        }
      };
    },
  });
});
const t0 = Date.now();
const note = (s) => {
  const line = `${((Date.now() - t0) / 1000).toFixed(1)}s ${s}`;
  log.push(line);
  if (process.env.LIVE) console.log(line);
};
page.on('console', (m) => (process.env.LIVE || m.text().includes('[hls-spike]')) && note(`console ${m.text().slice(0, 300)}`));
page.on('response', (r) => {
  const u = new URL(r.url());
  if (u.port === new URL(APP).port) return;
  const short = u.pathname.replace(/\/(v|s)\/[^/]+\//, '/$1/<token>/');
  note(`${r.request().method()} ${short} → ${r.status()}`);
});

const videoState = () => page.evaluate(() => {
  const find = (root) => {
    const v = root.querySelector('video');
    if (v) return v;
    for (const el of root.querySelectorAll('*')) {
      if (el.shadowRoot) {
        const found = find(el.shadowRoot);
        if (found) return found;
      }
    }
    return null;
  };
  const v = find(document);
  if (!v) return null;
  return {
    t: v.currentTime, paused: v.paused, w: v.videoWidth, h: v.videoHeight,
    err: v.error?.code ?? null, src: v.src.slice(0, 5),
    pip: v.disablePictureInPicture, controls: v.controls,
  };
});

async function waitFor(pred, ms, label) {
  const end = Date.now() + ms;
  let s;
  while (Date.now() < end) {
    s = await videoState();
    if (s && pred(s)) return s;
    await page.waitForTimeout(250);
  }
  throw new Error(`timeout waiting for ${label}; last state ${JSON.stringify(s)}`);
}

const codecs = await page.evaluate(() => ({
  h264: MediaSource.isTypeSupported('video/mp4; codecs="avc1.4d401f"'),
  aac: MediaSource.isTypeSupported('audio/mp4; codecs="mp4a.40.2"'),
}));
note(`MSE codecs ${JSON.stringify(codecs)}`);

let result = 'FAIL';
// recover: segments from #3 on fail (as if their presigned URLs expired during a long pause)
// until the app asks video-otp for a fresh playlist.
let otpCalls = 0;
let blocked = scenario === 'recover';
page.on('request', (r) => {
  if (!r.url().endsWith('/video-otp')) return;
  otpCalls++;
  if (otpCalls > 1 && blocked) { blocked = false; note('second video-otp → unblocked'); }
});
await page.route(/\/s\/[^/]+\/[0-9a-z]+_(\d+)\.ts$/, (route) => {
  const n = Number(route.request().url().match(/_(\d+)\.ts$/)[1]);
  return blocked && n >= 3 ? route.fulfill({ status: 403 }) : route.continue();
});
try {
  await page.goto(`${APP}/?autoplay=1&asset=${process.env.ASSET ?? 'demo1'}&user=Sara%20Ahmed&server=${encodeURIComponent(SERVER)}`);

  if (scenario === 'play') {
    const s = await waitFor((s) => s.t > 10, 40_000, 'playback past 10 s');
    note(`video state ${JSON.stringify(s)}`);
    await page.screenshot({ path: `${outDir}/web-play.png` });
    await page.waitForTimeout(2_600); // let the watermark jump once
    await page.screenshot({ path: `${outDir}/web-play-2.png` });
    result = 'PASS';
  } else if (scenario === 'recover') {
    const s = await waitFor((s) => s.t > 30 && !s.paused, 150_000, 'resume after recovery past 30 s');
    note(`video state ${JSON.stringify(s)}, video-otp calls ${otpCalls}`);
    result = otpCalls === 2 ? 'PASS' : 'FAIL';
  } else if (scenario === 'expire') {
    await waitFor((s) => s.t > 2, 40_000, 'playback started');
    note('waiting for token expiry (server TOKEN_TTL_S)');
    await page.waitForTimeout(Number(process.env.WAIT_MS ?? 20_000));
    // Same effect as an ABR down-switch, without depending on buffer state.
    const lvl = await page.evaluate(() => {
      const i = window.__hls.levels.findIndex((l) => l.height === 480);
      window.__hls.currentLevel = i;
      return i;
    });
    note(`forced switch to level ${lvl} (480p)`);
    const s = await waitFor((s) => s.t > 60 && !s.paused, 150_000, 'playback past 60 s');
    note(`video state ${JSON.stringify(s)}`);
    result = 'PASS';
  }
} catch (e) {
  note(`ERROR ${e.message}`);
  await page.screenshot({ path: `${outDir}/web-${scenario}-fail.png` }).catch(() => {});
} finally {
  console.log(log.join('\n'));
  console.log(`RESULT ${scenario}: ${result}`);
  await browser.close();
}
