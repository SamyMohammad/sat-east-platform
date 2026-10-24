import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.19';
import { R2Upload } from './r2_upload.ts';

Deno.test('C-2: upload PUTs every HLS file under canonical asset prefix with correct content type', async () => {
  const calls: { url: string; method: string; type: string }[] = [];
  const storage = new R2Upload({ accountId: 'account', accessKeyId: 'id', secretAccessKey: 'secret', bucket: 'videos' },
    () => Promise.resolve(new Uint8Array([1])), {
      fetch: (input, init) => {
        calls.push({ url: String(input), method: init?.method ?? '', type: new Headers(init?.headers).get('content-type')! });
        return Promise.resolve(new Response(null, { status: 200 }));
      },
    });
  await storage.upload('40000000-0000-0000-0000-000000000001', [
    { name: 'master.m3u8', path: 'master', bytes: 1 }, { name: '540p_000.ts', path: 'segment', bytes: 1 },
  ]);
  assertEquals(calls.map((c) => [c.method, c.type]), [['PUT', 'application/vnd.apple.mpegurl'], ['PUT', 'video/mp2t']]);
  assertEquals(calls[0].url, 'https://account.r2.cloudflarestorage.com/videos/videos/40000000-0000-0000-0000-000000000001/master.m3u8');
});

Deno.test('SEC-01: upload failure never includes remote response text or signing data', async () => {
  const storage = new R2Upload({ accountId: 'account', accessKeyId: 'id', secretAccessKey: 'secret', bucket: 'videos' },
    () => Promise.resolve(new Uint8Array()), { fetch: () => Promise.resolve(new Response('SECRET_REMOTE_ERROR', { status: 403 })) });
  const error = await assertRejects(() => storage.upload('40000000-0000-0000-0000-000000000001', [{ name: 'master.m3u8', path: 'master', bytes: 1 }]), Error);
  assertEquals(error.message.includes('SECRET'), false);
});
