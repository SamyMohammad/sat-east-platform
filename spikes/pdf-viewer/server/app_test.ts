// deno test -A spikes/pdf-viewer/server/
import { assert, assertEquals, assertMatch, assertRejects } from 'jsr:@std/assert@1.0.19';
import { PDFDocument } from 'npm:@cantoo/pdf-lib@2.11.1';
import { createApp, shortId } from './app.ts';
import { makeSamplePdf, stampPdf } from './stamp.ts';

const SECRET = 'pdf-test-secret-pdf-test-secret-xx';
const sample = await makeSamplePdf(3);

function setup(stamp = false) {
  const clock = { now: 1_000 };
  const logs: string[] = [];
  const app = createApp({
    files: (id) => Promise.resolve(id === 'notes1' ? sample : null),
    secret: SECRET, tokenTtlSeconds: 300, stamp, now: () => clock.now, log: (l) => logs.push(l),
  });
  return { app, clock, logs };
}

async function pdfUrl(app: ReturnType<typeof createApp>, assetId = 'notes1', user: string | null = 'Sara') {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (user) headers['x-spike-user'] = user;
  return await app.request('http://local/pdf-url', { method: 'POST', headers, body: JSON.stringify({ assetId }) });
}

async function textOf(bytes: Uint8Array): Promise<string> {
  const dir = await Deno.makeTempDir();
  await Deno.writeFile(`${dir}/f.pdf`, bytes);
  const out = await new Deno.Command('pdftotext', { args: ['-layout', `${dir}/f.pdf`, '-'] }).output();
  return new TextDecoder().decode(out.stdout);
}

Deno.test('SEC-02 pdf-url: needs a user and a known asset; returns a token URL and watermark', async () => {
  const { app } = setup();
  assertEquals((await pdfUrl(app, 'notes1', null)).status, 401);
  assertEquals((await pdfUrl(app, 'nope')).status, 403);
  assertEquals((await pdfUrl(app, '../x')).status, 400);
  const body = await (await pdfUrl(app)).json();
  assertMatch(body.url, /^http:\/\/local\/f\/[^/]+\/notes1\.pdf$/);
  assertEquals(body.expiresAt, 1_300);
  assertEquals(body.watermark, { name: 'Sara', shortId: await shortId('Sara') });
});

Deno.test('SEC-02 file: served inline, never cached; 403 once the URL expired', async () => {
  const { app, clock } = setup();
  const { url } = await (await pdfUrl(app)).json();
  const res = await app.request(url);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get('cache-control'), 'no-store');
  assertEquals(res.headers.get('content-disposition'), null);
  assertEquals(new Uint8Array(await res.arrayBuffer()), sample);
  clock.now += 300;
  assertEquals((await app.request(url)).status, 403);
});

Deno.test('SEC-02 file: tampered token or other asset name → 403', async () => {
  const { app } = setup();
  const { url } = await (await pdfUrl(app)).json();
  assertEquals((await app.request(url.replace('notes1.pdf', 'notes2.pdf'))).status, 403);
  const parts = url.split('/');
  parts[4] = parts[4].slice(0, -2) + (parts[4].endsWith('AA') ? 'BB' : 'AA');
  assertEquals((await app.request(parts.join('/'))).status, 403);
});

Deno.test('SEC-02 file: Range requests behave like Storage (206 + content-range)', async () => {
  const { app } = setup();
  const { url } = await (await pdfUrl(app)).json();
  const res = await app.request(url, { headers: { range: 'bytes=0-9' } });
  assertEquals(res.status, 206);
  assertEquals(res.headers.get('content-range'), `bytes 0-9/${sample.length}`);
  assertEquals(new Uint8Array(await res.arrayBuffer()), sample.slice(0, 10));
  assertEquals((await app.request(url, { headers: { range: 'bytes=x' } })).status, 416);
});

Deno.test('SEC-02 stamp: every page carries the student id; original untouched', async () => {
  const { app } = setup(true);
  const { url } = await (await pdfUrl(app)).json();
  const bytes = new Uint8Array(await (await app.request(url)).arrayBuffer());
  const id = await shortId('Sara');
  const pages = (await textOf(bytes)).split('\f').filter((p) => p.trim());
  assertEquals(pages.length, 3);
  for (const p of pages) assert(p.includes(`Licensed to student ${id}`), 'footer on every page');
  assert(!(await textOf(sample)).includes('Licensed to'));
  assertEquals((await PDFDocument.load(bytes)).getPageCount(), 3);
});

Deno.test('SEC-02 stamp: non-Latin text (Arabic names) is refused, not silently written as ????', async () => {
  await assertRejects(() => stampPdf(sample, 'سارة أحمد', 'x'));
});
