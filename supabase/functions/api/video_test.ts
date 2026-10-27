import { assert, assertEquals, assertMatch, assertRejects } from 'jsr:@std/assert@1.0.19';
import { type Caller, createApp, type Deps } from './app.ts';
import { R2Storage } from './video/r2.ts';
import { signToken, type TokenPayload, verifyToken } from './video/token.ts';

const ASSET = '40000000-0000-0000-0000-000000000001';
const PREFIX = `videos/${ASSET}`;
const SECRET = 'test-video-secret-only';
const KEY = Uint8Array.from({ length: 16 }, (_, i) => i);
const PAYLOAD: TokenPayload = {
  k: 'p', a: ASSET, u: 'student', t: 1000, e: 15400,
  key_ttl_s: 300, playlist_ttl_s: 14400,
};
const GRANT = {
  ok: true, provider: 'r2_hls', asset_id: ASSET, user_id: 'student',
  watermark: { name: 'Student', short_id: 'ABC123' },
  key_ttl_s: 300, playlist_ttl_s: 14400, resume_s: 45,
};
type RpcResult = Awaited<ReturnType<Caller['rpc']>>;

function setup(options: {
  signedIn?: boolean;
  rpc?: (fn: string) => RpcResult;
  appCheck?: Deps['appCheck'];
  media?: string;
  storageError?: 'list' | 'delete' | 'get';
  missingVideo?: boolean;
  missingKey?: boolean;
  allowedOrigins?: string[];
} = {}) {
  const events: string[] = [];
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  const reports: unknown[] = [];
  const logs: string[] = [];
  const clock = { now: 1000 };
  const app = createApp({
    appCheck: options.appCheck ?? { projectNumber: undefined, mode: 'monitor' },
    videoAllowedOrigins: options.allowedOrigins,
    authenticate: () => {
      events.push('auth');
      return Promise.resolve(options.signedIn === false ? null : {
        userId: 'student',
        rpc: (fn, args) => {
          calls.push({ fn, args });
          events.push(fn);
          return Promise.resolve(options.rpc?.(fn) ?? {
            data: fn === 'teacher_video_prefix' ? { provider: 'r2_hls', r2_prefix: PREFIX }
              : fn === 'teacher_delete_video' ? { ok: true } : GRANT,
            error: null,
          });
        },
      });
    },
    log: (line) => logs.push(line),
    reportError: (error) => { reports.push(error); return Promise.resolve(); },
    video: options.missingVideo ? undefined : {
      secret: SECRET, supabaseUrl: 'https://project.supabase.co', now: () => clock.now,
      serviceKey: (id) => {
        events.push(`key:${id}`);
        return Promise.resolve(options.missingKey ? null : { key: KEY, prefix: PREFIX });
      },
      storage: {
        getText: (prefix, file) => {
          events.push(`get:${prefix}/${file}`);
          if (options.storageError === 'get') throw new Error('SECRET_STORAGE_URL');
          return Promise.resolve(file === 'master.m3u8' ? '#EXTM3U\n540p.m3u8\n'
            : options.media ?? '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key"\nclip_000.ts\n');
        },
        segmentUrl: (prefix, file, ttl) => {
          events.push(`sign:${prefix}/${file}:${ttl}`);
          return Promise.resolve(`https://r2.test/${prefix}/${file}?signed`);
        },
        presignPut: (prefix, file, ttl) => {
          events.push(`put:${prefix}/${file}:${ttl}`);
          return Promise.resolve(`https://r2.test/${prefix}/${file}?upload`);
        },
        list: (prefix) => {
          events.push(`list:${prefix}`);
          if (options.storageError === 'list') throw new Error('SECRET_STORAGE_URL');
          return Promise.resolve([`${PREFIX}/clip_000.ts`]);
        },
        delete: (keys) => {
          events.push(`delete:${keys.join(',')}`);
          if (options.storageError === 'delete') throw new Error('SECRET_STORAGE_URL');
          return Promise.resolve();
        },
      },
    },
  });
  const post = (path = 'video-otp', body: unknown = { asset_id: ASSET }) =>
    app.request(`https://untrusted-origin.test/api/${path}`, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
    });
  const get = (token: string, file: string) => app.request(`https://local/api/v/${token}/${file}`);
  return { app, post, get, clock, calls, events, reports, logs };
}

Deno.test('SEC-01: OTP uses configured Supabase URL and embeds grant TTLs in signed token', async () => {
  const s = setup();
  const res = await s.post();
  assertEquals(res.status, 200);
  const body = await res.json();
  assertMatch(body.hls_url, /^https:\/\/project\.supabase\.co\/functions\/v1\/api\/v\/[^/]+\/master\.m3u8$/);
  assertEquals(body, {
    provider: 'r2_hls', hls_url: body.hls_url, expires_at: 15400,
    watermark: GRANT.watermark, resume_s: 45,
  });
  const token = body.hls_url.split('/').at(-2);
  assertEquals(await verifyToken(token, SECRET, 1000), PAYLOAD);
  assertEquals(s.calls, [{ fn: 'video_playback_grant', args: { p_asset_id: ASSET } }]);
  assertEquals(s.events, ['auth', 'video_playback_grant']);
});

Deno.test('SEC-01: YouTube returns only embed fields and resume position', async () => {
  const s = setup({ rpc: () => ({ data: { ok: true, provider: 'youtube', youtube_id: 'abcdefgh_-1', resume_s: 9 }, error: null }) });
  assertEquals(await (await s.post()).json(), { provider: 'youtube', youtube_id: 'abcdefgh_-1', resume_s: 9 });
});

Deno.test('SEC-01: OTP authentication and App Check run before RPC', async () => {
  const unauth = setup({ signedIn: false });
  assertEquals((await unauth.post()).status, 401);
  assertEquals(unauth.calls, []);
  const blocked = setup({ appCheck: { projectNumber: '123', mode: 'enforce' } });
  assertEquals((await blocked.post()).status, 403);
  assertEquals(blocked.calls, []);
  assertEquals(blocked.logs, ['app-check enforce video-otp: missing']);
});

for (const code of ['forbidden', 'device_revoked', 'not_enrolled', 'topic_locked', 'access_expired', 'video_needed']) {
  Deno.test(`SEC-01: OTP maps raised ${code}`, async () => {
    const s = setup({ rpc: () => ({ data: null, error: { message: code } }) });
    const res = await s.post();
    assertEquals(res.status, code === 'forbidden' ? 403 : 400);
    assertEquals((await res.json()).error.code, code);
  });
}

Deno.test('SEC-01: returned rate limit keeps existing HTTP 400 mapping', async () => {
  const s = setup({ rpc: () => ({ data: { ok: false, error: 'rate_limited' }, error: null }) });
  const res = await s.post();
  assertEquals([res.status, (await res.json()).error.code], [400, 'rate_limited']);
});

Deno.test('SEC-01: unknown RPC errors and missing config fail safely', async () => {
  const broken = setup({ rpc: () => ({ data: null, error: { message: 'SECRET_KEY_HEX', code: '08006' } }) });
  const res = await broken.post();
  assertEquals([res.status, (await res.json()).error.code], [500, 'internal']);
  assertEquals(JSON.stringify(broken.reports).includes('SECRET_KEY_HEX'), false);
  const missing = setup({ missingVideo: true });
  assertEquals((await missing.post()).status, 500);
  assertEquals((await missing.get('anything', 'key')).status, 500);
  assertEquals((await missing.post('teacher/video-delete')).status, 500);
  assertEquals((await missing.post('register-device', { fingerprint: 'test-fingerprint-1234' })).status, 200);
});

// Sign arbitrary payloads to test verification of authentic but invalid token kinds/shapes.
async function rawToken(payload: Record<string, unknown>) {
  const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  const body = encode(new TextEncoder().encode(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return `${body}.${encode(new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body))))}`;
}

Deno.test('SEC-01: tampered, expired and wrong-kind tokens cannot read keys or playlists', async () => {
  const valid = await signToken(PAYLOAD, SECRET);
  const invalid = [
    `x${valid}`, await rawToken({ ...PAYLOAD, e: 1000 }),
    await rawToken({ ...PAYLOAD, k: 's' }), await rawToken({ ...PAYLOAD, t: 1001 }),
    await rawToken({ ...PAYLOAD, key_ttl_s: -1 }),
    await rawToken({ ...PAYLOAD, a: '../other' }),
  ];
  for (const token of invalid) {
    const s = setup();
    assertEquals((await s.get(token, 'key')).status, 403);
    assertEquals((await s.get(token, 'master.m3u8')).status, 403);
    assertEquals(s.events, []);
  }
});

Deno.test('SEC-01: key TTL boundary and longer playlist session; both never cached', async () => {
  const s = setup();
  const token = await signToken(PAYLOAD, SECRET);
  s.clock.now = 1300;
  const res = await s.get(token, 'key');
  assertEquals(res.status, 200);
  assertEquals(res.headers.get('cache-control'), 'no-store');
  assertEquals(res.headers.get('content-type'), 'application/octet-stream');
  assertEquals(new Uint8Array(await res.arrayBuffer()), KEY);
  s.clock.now = 1301;
  assertEquals((await s.get(token, 'key')).status, 403);
  const master = await s.get(token, 'master.m3u8');
  assertEquals(master.status, 200);
  assertEquals(master.headers.get('cache-control'), 'no-store');
  assertEquals(await master.text(), '#EXTM3U\n540p.m3u8\n');
  s.clock.now = 15400;
  assertEquals((await s.get(token, 'master.m3u8')).status, 403);
});

Deno.test('SEC-01: media segments use canonical prefix and token playlist TTL; key URI preserved', async () => {
  const s = setup();
  const res = await s.get(await signToken(PAYLOAD, SECRET), '540p.m3u8');
  assertEquals(res.headers.get('cache-control'), 'no-store');
  const text = await res.text();
  assert(text.includes('URI="key"'));
  assert(text.includes(`https://r2.test/${PREFIX}/clip_000.ts?signed`));
  assertEquals(s.events, [`get:${PREFIX}/540p.m3u8`, `sign:${PREFIX}/clip_000.ts:14400`]);
});

Deno.test('SEC-01: malformed filenames never reach storage', async () => {
  const s = setup();
  const token = await signToken(PAYLOAD, SECRET);
  for (const file of ['bad.exe', 'bad.name.m3u8', '%2e%2e%2fsecret.m3u8']) {
    assert([400, 404].includes((await s.get(token, file)).status));
  }
  assertEquals(s.events, []);
});

Deno.test('SEC-01: unexpected segment URI returns internal without leaking content or reporting it', async () => {
  const s = setup({ media: '#EXTM3U\nSECRET_PRIVATE_PATH.mp4' });
  const res = await s.get(await signToken(PAYLOAD, SECRET), '540p.m3u8');
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error.code, 'internal');
  assertEquals(s.logs, []);
  assertEquals(JSON.stringify(s.reports).includes('SECRET_PRIVATE_PATH'), false);
});

Deno.test('SEC-01: missing key refuses playback', async () => {
  const s = setup({ missingKey: true });
  assertEquals((await s.get(await signToken(PAYLOAD, SECRET), 'key')).status, 403);
});

Deno.test('SEC-01: CORS preflight on all video routes allows required headers', async () => {
  for (const path of ['video-otp', 'v/token/key', 'teacher/video-delete']) {
    const s = setup({ allowedOrigins: ['https://student.test'] });
    const res = await s.app.request(`https://local/api/${path}`, { method: 'OPTIONS', headers: {
      origin: 'https://student.test', 'access-control-request-method': 'POST',
      'access-control-request-headers': 'authorization,content-type,x-client-info,apikey,x-firebase-appcheck,x-device-id',
    } });
    assertEquals(res.status, 204);
    assertEquals(res.headers.get('access-control-allow-origin'), 'https://student.test');
    assert(res.headers.get('access-control-allow-headers')?.includes('x-firebase-appcheck'));
    assert(res.headers.get('access-control-allow-headers')?.includes('x-device-id'));
    assertEquals(s.events, []);
    const blocked = await s.app.request(`https://local/api/${path}`, { method: 'OPTIONS', headers: { origin: 'https://evil.test' } });
    assertEquals(blocked.headers.get('access-control-allow-origin'), null);
  }
});

Deno.test('C-2: non-teacher deletion stops before R2', async () => {
  const s = setup({ rpc: () => ({ data: null, error: { message: 'forbidden' } }) });
  assertEquals((await s.post('teacher/video-delete')).status, 403);
  assertEquals(s.events, ['auth', 'teacher_video_prefix']);
});

for (const storageError of ['list', 'delete'] as const) {
  Deno.test(`C-2: R2 ${storageError} failure leaves DB asset for retry`, async () => {
    const s = setup({ storageError });
    assertEquals((await s.post('teacher/video-delete')).status, 500);
    assertEquals(s.calls.map((c) => c.fn), ['teacher_video_prefix']);
    assertEquals(JSON.stringify(s.reports).includes('SECRET_STORAGE_URL'), false);
  });
}

Deno.test('C-2: R2 deletion completes before DB deletion', async () => {
  const s = setup();
  assertEquals(await (await s.post('teacher/video-delete')).json(), { ok: true });
  assertEquals(s.events, ['auth', 'teacher_video_prefix', `list:${PREFIX}/`, `delete:${PREFIX}/clip_000.ts`, 'teacher_delete_video']);
});

Deno.test('C-2: YouTube deletion skips R2', async () => {
  const s = setup({ rpc: (fn) => ({ data: fn === 'teacher_video_prefix' ? { provider: 'youtube', r2_prefix: null } : { ok: true }, error: null }) });
  assertEquals((await s.post('teacher/video-delete')).status, 200);
  assertEquals(s.events, ['auth', 'teacher_video_prefix', 'teacher_delete_video']);
});

Deno.test('C-2: R2 ListObjectsV2 paginates, decodes object names, and deletes individual objects', async () => {
  const requests: URL[] = [];
  const deleted: string[] = [];
  const storage = new R2Storage({ accountId: 'account', accessKeyId: 'test', secretAccessKey: 'test', bucket: 'videos' }, {
    fetch: (input, init) => {
      const url = new URL(String(input));
      if (init?.method === 'DELETE') {
        deleted.push(decodeURIComponent(url.pathname));
        return Promise.resolve(new Response(null, { status: 204 }));
      }
      requests.push(url);
      return Promise.resolve(new Response(requests.length === 1
        ? `<ListBucketResult><Contents><Key>${encodeURIComponent(`${PREFIX}/one.ts`)}</Key></Contents><IsTruncated>true</IsTruncated><NextContinuationToken>a&amp;b</NextContinuationToken></ListBucketResult>`
        : `<ListBucketResult><Contents><Key>${encodeURIComponent(`${PREFIX}/two.ts`)}</Key></Contents><IsTruncated>false</IsTruncated></ListBucketResult>`));
    },
    sign: (input) => Promise.resolve(new Request(String(input))),
  });
  const keys = await storage.list(`${PREFIX}/`);
  assertEquals(keys, [`${PREFIX}/one.ts`, `${PREFIX}/two.ts`]);
  assertEquals(requests[0].searchParams.get('list-type'), '2');
  assertEquals(requests[0].searchParams.get('prefix'), `${PREFIX}/`);
  assertEquals(requests[1].searchParams.get('continuation-token'), 'a&b');
  await storage.delete(keys);
  assertEquals(deleted, [`/videos/${PREFIX}/one.ts`, `/videos/${PREFIX}/two.ts`]);
});

Deno.test('SEC-01: R2 presigns GET with requested expiry and uses canonical object paths', async () => {
  const storage = new R2Storage({ accountId: 'account', accessKeyId: 'test', secretAccessKey: 'test', bucket: 'videos' });
  const url = new URL(await storage.segmentUrl(PREFIX, 'clip_000.ts', 14400));
  assertEquals(url.pathname, `/videos/${PREFIX}/clip_000.ts`);
  assertEquals(url.searchParams.get('X-Amz-Expires'), '14400');
  assert(url.searchParams.has('X-Amz-Signature'));
});

Deno.test('C-2: truncated R2 listing without continuation token fails instead of deleting partially', async () => {
  const storage = new R2Storage({ accountId: 'account', accessKeyId: 'test', secretAccessKey: 'test', bucket: 'videos' }, {
    fetch: () => Promise.resolve(new Response('<ListBucketResult><IsTruncated>true</IsTruncated></ListBucketResult>')),
    sign: (input) => Promise.resolve(new Request(String(input))),
  });
  await assertRejects(() => storage.list(`${PREFIX}/`));
});

Deno.test('C-2: missing R2 truncation flag fails closed', async () => {
  const storage = new R2Storage({ accountId: 'account', accessKeyId: 'test', secretAccessKey: 'test', bucket: 'videos' }, {
    fetch: () => Promise.resolve(new Response('<ListBucketResult></ListBucketResult>')),
    sign: (input) => Promise.resolve(new Request(String(input))),
  });
  await assertRejects(() => storage.list(`${PREFIX}/`));
});

const UPLOAD_FILES = ['master.m3u8', '540p.m3u8', '540p_000.ts'];
Deno.test('C-2: upload URLs require auth and teacher grant before signing', async () => {
  const anonymous = setup({ signedIn: false });
  assertEquals((await anonymous.post('teacher/video-upload-urls', { asset_id: ASSET, files: UPLOAD_FILES })).status, 401);
  assertEquals(anonymous.calls, []);
  const student = setup({ rpc: () => ({ data: null, error: { message: 'forbidden' } }) });
  assertEquals((await student.post('teacher/video-upload-urls', { asset_id: ASSET, files: UPLOAD_FILES })).status, 403);
  assertEquals(student.events, ['auth', 'teacher_video_upload_grant']);
});

for (const [name, files] of [
  ['bad name', ['master.m3u8', '../key.ts']], ['missing master', ['540p.m3u8']],
  ['empty', []], ['duplicate', ['master.m3u8', 'master.m3u8']],
  ['too many', ['master.m3u8', ...Array.from({ length: 2000 }, (_, i) => `segment_${i}.ts`)]],
  ['long name', ['master.m3u8', `${'a'.repeat(65)}.ts`]], ['not strings', ['master.m3u8', 1]],
] as const) {
  Deno.test(`C-2: upload URLs reject ${name} before RPC`, async () => {
    const s = setup();
    assertEquals((await s.post('teacher/video-upload-urls', { asset_id: ASSET, files })).status, 400);
    assertEquals(s.calls, []);
  });
}

Deno.test('C-2: upload URLs reject invalid asset UUID before RPC', async () => {
  const s = setup();
  assertEquals((await s.post('teacher/video-upload-urls', { asset_id: 'bad', files: UPLOAD_FILES })).status, 400);
  assertEquals(s.calls, []);
});

Deno.test('C-2: upload URLs use grant prefix and expiry for every requested file', async () => {
  const s = setup({ rpc: () => ({ data: { r2_prefix: PREFIX, ttl_s: 900 }, error: null }) });
  const res = await s.post('teacher/video-upload-urls', { asset_id: ASSET, files: UPLOAD_FILES });
  assertEquals(res.status, 200);
  assertEquals(res.headers.get('cache-control'), 'no-store');
  assertEquals(await res.json(), { urls: Object.fromEntries(UPLOAD_FILES.map((f) => [f, `https://r2.test/${PREFIX}/${f}?upload`])), expires_in: 900 });
  assertEquals(s.calls, [{ fn: 'teacher_video_upload_grant', args: { p_asset_id: ASSET } }]);
  assertEquals(s.events.slice(2), UPLOAD_FILES.map((f) => `put:${PREFIX}/${f}:900`));
  assertEquals(s.logs, []);
});

Deno.test('C-2: upload URLs map RPC errors and require video configuration', async () => {
  for (const [message, status] of [['invalid_input', 400], ['rate_limited', 400], ['unknown', 500]] as const) {
    const s = setup({ rpc: () => ({ data: null, error: { message } }) });
    assertEquals((await s.post('teacher/video-upload-urls', { asset_id: ASSET, files: UPLOAD_FILES })).status, status);
  }
  const s = setup({ missingVideo: true });
  assertEquals((await s.post('teacher/video-upload-urls', { asset_id: ASSET, files: UPLOAD_FILES })).status, 500);
});

Deno.test('C-2: R2 presigns PUT with grant expiry and canonical key', async () => {
  const methods: string[] = [];
  const storage = new R2Storage({ accountId: 'account', accessKeyId: 'test', secretAccessKey: 'test', bucket: 'videos' }, {
    fetch: () => Promise.reject(new Error('No network')),
    sign: (input, init) => { methods.push(init?.method ?? ''); return Promise.resolve(new Request(String(input))); },
  });
  const url = new URL(await storage.presignPut(PREFIX, 'master.m3u8', 900));
  assertEquals(methods, ['PUT']);
  assertEquals(url.pathname, `/videos/${PREFIX}/master.m3u8`);
  assertEquals(url.searchParams.get('X-Amz-Expires'), '900');
});
