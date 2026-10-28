import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.19';
import { PresignedUpload } from './r2_upload.ts';
const FILES = [{ name: 'master.m3u8', path: 'master', bytes: 1 }, { name: '540p_000.ts', path: 'segment', bytes: 1 }];
const URLS = { 'master.m3u8': 'https://storage.test/master?SECRET_SIGNATURE', '540p_000.ts': 'https://storage.test/segment?SECRET_SIGNATURE' };

Deno.test('C-2: PUT uses issued URLs and content types without user authorization', async () => {
  const calls: unknown[] = [];
  const storage = new PresignedUpload(() => Promise.resolve(new Uint8Array([1])), (input, init) => {
    const headers = new Headers(init?.headers);
    calls.push([String(input), init?.method, headers.get('content-type'), headers.get('authorization')]);
    return Promise.resolve(new Response(null, { status: 200 }));
  });
  await storage.upload(FILES, URLS);
  assertEquals(calls, [[URLS['master.m3u8'], 'PUT', 'application/vnd.apple.mpegurl', null], [URLS['540p_000.ts'], 'PUT', 'video/mp2t', null]]);
});
Deno.test('SEC-01: non-2xx and thrown PUT failures never expose URLs or response text', async () => {
  for (const status of [302, 403, 500]) {
    const storage = new PresignedUpload(() => Promise.resolve(new Uint8Array()), () => Promise.resolve(new Response('SECRET_REMOTE_ERROR', { status })));
    const error = await assertRejects(() => storage.upload(FILES, URLS), Error);
    assertEquals(error.message.includes('SECRET'), false);
    assertEquals(error.message.includes('https://'), false);
  }
  const storage = new PresignedUpload(() => Promise.resolve(new Uint8Array()), () => Promise.reject(new Error(URLS['master.m3u8'])));
  assertEquals((await assertRejects(() => storage.upload(FILES, URLS), Error)).message.includes('SECRET'), false);
});
Deno.test('C-2: a failed PUT reports its HTTP status and S3 error code only', async () => {
  const body = '<Error><Code>SignatureDoesNotMatch</Code><Message>SECRET_REMOTE_ERROR</Message></Error>';
  const storage = new PresignedUpload(() => Promise.resolve(new Uint8Array()), () => Promise.resolve(new Response(body, { status: 403 })));
  const error = await assertRejects(() => storage.upload(FILES, URLS), Error);
  assertEquals(error.message.includes('(HTTP 403 SignatureDoesNotMatch)'), true);
  assertEquals(error.message.includes('SECRET'), false);
  const bare = new PresignedUpload(() => Promise.resolve(new Uint8Array()), () => Promise.resolve(new Response('SECRET_REMOTE_ERROR', { status: 500 })));
  assertEquals((await assertRejects(() => bare.upload(FILES, URLS), Error)).message.includes('(HTTP 500)'), true);
});
Deno.test('C-2: uploads run at most four in parallel and finish every file', async () => {
  const files = Array.from({ length: 9 }, (_, i) => ({ name: `segment_${i}.ts`, path: String(i), bytes: 1 }));
  const urls = Object.fromEntries(files.map((f) => [f.name, `https://storage.test/${f.name}`]));
  let active = 0, peak = 0, finished = 0;
  const pending: (() => void)[] = [];
  const storage = new PresignedUpload(() => Promise.resolve(new Uint8Array()), () => {
    active++; peak = Math.max(peak, active);
    return new Promise<Response>((resolve) => pending.push(() => { active--; finished++; resolve(new Response(null, { status: 200 })); }));
  });
  const work = storage.upload(files, urls);
  while (finished < files.length) { await Promise.resolve(); pending.shift()?.(); }
  await work;
  assertEquals(peak, 4);
  assertEquals(finished, files.length);
});
Deno.test('C-2: a failed PUT waits for other in-flight PUTs before rollback', async () => {
  let release: (() => void) | undefined;
  let finished = false;
  const storage = new PresignedUpload(() => Promise.resolve(new Uint8Array()), (url) => {
    if (String(url).includes('/master')) return Promise.resolve(new Response(null, { status: 500 }));
    return new Promise<Response>((resolve) => { release = () => resolve(new Response(null, { status: 200 })); });
  });
  const work = assertRejects(() => storage.upload(FILES, URLS), Error).then(() => { finished = true; });
  while (!release) await Promise.resolve();
  await Promise.resolve();
  assertEquals(finished, false);
  release();
  await work;
  assertEquals(finished, true);
});
