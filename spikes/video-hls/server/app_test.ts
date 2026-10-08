// deno test -A spikes/video-hls/server/
import { assert, assertEquals, assertMatch } from 'jsr:@std/assert@1.0.19';
import { createApp, type Deps } from './app.ts';
import { rewriteMediaPlaylist } from './playlist.ts';
import { LocalStorage } from './storage.ts';
import { signToken, verifyToken } from './token.ts';

const SECRET = 'test-secret-test-secret-test-secret!';
const KEY = Uint8Array.from({ length: 16 }, (_, i) => i);
const MEDIA = [
  '#EXTM3U', '#EXT-X-KEY:METHOD=AES-128,URI="key",IV=0x00000000000000000000000000000000',
  '#EXTINF:6.0,', '720p_000.ts', '#EXTINF:6.0,', '720p_001.ts', '#EXT-X-ENDLIST',
].join('\n');

async function fixture(now = 1_000) {
  const dir = await Deno.makeTempDir();
  await Deno.mkdir(`${dir}/demo`);
  await Deno.writeTextFile(`${dir}/demo/master.m3u8`, '#EXTM3U\n720p.m3u8\n');
  await Deno.writeTextFile(`${dir}/demo/720p.m3u8`, MEDIA);
  await Deno.writeFile(`${dir}/demo/720p_000.ts`, new Uint8Array([1, 2, 3]));
  const clock = { now };
  const deps: Deps = {
    storage: new LocalStorage(dir, SECRET, () => clock.now),
    keys: (id) => Promise.resolve(id === 'demo' ? KEY : null),
    secret: SECRET,
    tokenTtlSeconds: 300,
    segmentTtlSeconds: 3600,
    now: () => clock.now,
  };
  return { app: createApp(deps), clock };
}

async function otp(app: ReturnType<typeof createApp>, assetId = 'demo', user: string | null = 'Sara') {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  if (user) headers['x-spike-user'] = user;
  return await app.request('http://local/video-otp', { method: 'POST', headers, body: JSON.stringify({ assetId }) });
}

async function playlistBase(app: ReturnType<typeof createApp>) {
  const { playlistUrl } = await (await otp(app)).json();
  return playlistUrl.replace(/master\.m3u8$/, '');
}

Deno.test('token: round trip, expiry, tamper, wrong kind', async () => {
  const t = await signToken({ k: 'p', a: 'demo', u: 'Sara', e: 100 }, SECRET);
  assertEquals((await verifyToken(t, SECRET, 99, 'p'))?.a, 'demo');
  assertEquals(await verifyToken(t, SECRET, 100, 'p'), null, 'expired at e');
  assertEquals(await verifyToken(t, SECRET, 99, 's'), null, 'wrong kind');
  assertEquals(await verifyToken(t, 'another-secret-another-secret-xx', 99, 'p'), null);
  const [body, sig] = t.split('.');
  const forged = btoa(JSON.stringify({ k: 'p', a: 'other', u: 'Sara', e: 100 })).replace(/=+$/, '');
  assertEquals(await verifyToken(`${forged}.${sig}`, SECRET, 99, 'p'), null);
  assertEquals(await verifyToken(`${body}.${sig}.x`, SECRET, 99, 'p'), null);
  assertEquals(await verifyToken('garbage', SECRET, 99, 'p'), null);
});

Deno.test('playlist rewrite: segments signed, tags and key uri untouched', async () => {
  const out = await rewriteMediaPlaylist(MEDIA, (n) => Promise.resolve(`https://cdn/${n}?sig`));
  assert(out.includes('URI="key"'));
  assert(out.includes('https://cdn/720p_000.ts?sig'));
  assert(out.includes('#EXT-X-ENDLIST'));
});

Deno.test('playlist rewrite: refuses paths outside the asset folder', async () => {
  let threw = false;
  try {
    await rewriteMediaPlaylist('#EXTM3U\n../other/720p_000.ts', (n) => Promise.resolve(n));
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test('video-otp: requires a user and a known asset', async () => {
  const { app } = await fixture();
  assertEquals((await otp(app, 'demo', null)).status, 401);
  assertEquals((await otp(app, 'nope')).status, 403);
  assertEquals((await otp(app, '../demo')).status, 400);
  const res = await otp(app);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertMatch(body.playlistUrl, /^http:\/\/local\/v\/[^/]+\/master\.m3u8$/);
  assertEquals(body.expiresAt, 1_300);
  assertEquals(body.watermark.name, 'Sara');
});

Deno.test('key: served with a valid token, never cached; 403 after expiry', async () => {
  const { app, clock } = await fixture();
  const base = await playlistBase(app);
  const res = await app.request(`${base}key`);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get('cache-control'), 'no-store');
  assertEquals(new Uint8Array(await res.arrayBuffer()), KEY);
  clock.now += 300;
  assertEquals((await app.request(`${base}key`)).status, 403);
});

Deno.test('media playlist: segment urls are signed and fetchable; key route rejects them', async () => {
  const { app } = await fixture();
  const base = await playlistBase(app);
  const text = await (await app.request(`${base}720p.m3u8`)).text();
  const segUrl = text.split('\n').find((l) => l.startsWith('http'))!;
  assertMatch(segUrl, /^http:\/\/local\/s\/[^/]+\/720p_000\.ts$/);
  const seg = await app.request(segUrl);
  assertEquals(seg.status, 200);
  assertEquals(new Uint8Array(await seg.arrayBuffer()), new Uint8Array([1, 2, 3]));
  // A segment token must not open the key or the playlists.
  const segToken = segUrl.split('/')[4];
  assertEquals((await app.request(`http://local/v/${segToken}/key`)).status, 403);
  assertEquals((await app.request(`http://local/v/${segToken}/master.m3u8`)).status, 403);
  // A segment token is bound to its file.
  assertEquals((await app.request(`http://local/s/${segToken}/720p_001.ts`)).status, 403);
});

Deno.test('segments outlive the playback token (pause/resume)', async () => {
  const { app, clock } = await fixture();
  const base = await playlistBase(app);
  const text = await (await app.request(`${base}720p.m3u8`)).text();
  const segUrl = text.split('\n').find((l) => l.startsWith('http'))!;
  clock.now += 1_800;
  assertEquals((await app.request(`${base}720p.m3u8`)).status, 403);
  assertEquals((await app.request(segUrl)).status, 200);
  clock.now += 1_800;
  assertEquals((await app.request(segUrl)).status, 403);
});
