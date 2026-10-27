import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.19';
import { publish, type PublishDeps, sizeMb, ToolError } from './publish.ts';
import { PresignedUpload } from './r2_upload.ts';

const ID = '40000000-0000-0000-0000-000000000001';
const REQUEST = { topicId: ID, title: 'Lesson', input: 'clip.mp4', dryRun: false };

function setup(options: { quotaFull?: boolean; rejected?: boolean; fail?: 'pack' | 'upload' | 'confirm' | 'delete' } = {}) {
  const events: string[] = [];
  const confirmations: string[] = [];
  const key = Uint8Array.from({ length: 16 }, (_, i) => i);
  let quotaCalls = 0;
  const deps: PublishDeps = {
    probe: () => { events.push('probe'); return Promise.resolve(31); },
    pack: (_input, output, keyDir, bytes) => {
      events.push(`pack:${output}:${keyDir}`);
      assertEquals(Array.from(bytes), Array.from({ length: 16 }, (_, i) => i));
      if (options.fail === 'pack') throw new Error('SECRET_RAW_ERROR');
      return Promise.resolve();
    },
    randomKey: () => key,
    fs: {
      tempDir: () => { const dir = `temp-${events.filter((e) => e.startsWith('temp:')).length}`; events.push(`temp:${dir}`); return Promise.resolve(dir); },
      prepareOutput: (dir) => { events.push(`output:${dir}`); return Promise.resolve(); },
      files: () => Promise.resolve([{ name: 'master.m3u8', path: 'master', bytes: 100 }, { name: '540p_000.ts', path: 'segment', bytes: 1048576 }]),
      remove: (dir) => { events.push(`remove:${dir}`); return Promise.resolve(); },
    },
    storage: { upload: () => {
      events.push('upload');
      if (options.fail === 'upload' || options.fail === 'delete') throw new Error('SECRET_RAW_ERROR');
      return Promise.resolve();
    } },
    api: () => {
      events.push('sign-in');
      return Promise.resolve({
        quota: () => { events.push('quota'); return Promise.resolve({ used_mb: options.quotaFull ? 100 : quotaCalls++ ? 12 : 10, cap_mb: 100 }); },
        create: (args) => {
          events.push('create');
          assertEquals(args, { p_topic_id: ID, p_subtopic_id: null, p_title: 'Lesson', p_duration_s: 31, p_size_mb: 2 });
          return Promise.resolve(options.rejected ? { ok: false as const, error: 'quota_exceeded' as const, used_mb: 99, cap_mb: 100 } : { ok: true as const, asset_id: ID });
        },
        confirm: (_id, hex) => { events.push('confirm'); confirmations.push(hex); if (options.fail === 'confirm') throw new Error('SECRET_RAW_ERROR'); return Promise.resolve(); },
        uploadUrls: (_id, names) => {
          events.push('upload-urls');
          assertEquals(names, ['master.m3u8', '540p_000.ts']);
          return Promise.resolve(Object.fromEntries(names.map((name) => [name, `https://storage.test/${name}?SECRET_SIGNATURE`])));
        },
        delete: (id) => { events.push(`delete:${id}`); if (options.fail === 'delete') throw new Error('SECRET_DELETE_ERROR'); return Promise.resolve(); },
        list: () => Promise.resolve([]),
      });
    },
  };
  return { deps, events, confirmations, key };
}

Deno.test('C-2: size is ceiling of summed bytes, not sum of rounded file sizes', () => {
  assertEquals(sizeMb([1, 1048575]), 1);
  assertEquals(sizeMb([1048576, 1]), 2);
});

Deno.test('C-2: quota stops before reservation and upload; temporary key directory removed', async () => {
  const s = setup({ quotaFull: true });
  const error = await assertRejects(() => publish(REQUEST, s.deps), ToolError);
  assertEquals(error.code, 'quota_exceeded');
  assertEquals(error.message.includes('100'), true);
  assertEquals(s.events.includes('create'), false);
  assertEquals(s.events.includes('upload'), false);
  assertEquals(s.events.at(-1), 'remove:temp-0');
  assertEquals(Array.from(s.key), Array(16).fill(0));
});

Deno.test('C-2: create quota race returns used/cap without upload', async () => {
  const s = setup({ rejected: true });
  const error = await assertRejects(() => publish(REQUEST, s.deps), ToolError);
  assertEquals(error.code, 'quota_exceeded');
  assertEquals(error.message.includes('99 MB used / 100 MB cap'), true);
  assertEquals(s.events.includes('upload'), false);
  assertEquals(s.events.some((e) => e.startsWith('delete:')), false);
});

for (const fail of ['upload', 'confirm', 'delete'] as const) {
  Deno.test(`C-2: ${fail} failure releases reservation or provides its id for retry`, async () => {
    const s = setup({ fail });
    const error = await assertRejects(() => publish(REQUEST, s.deps), ToolError);
    assertEquals(error.assetId, ID);
    assertEquals(error.message.includes('SECRET'), false);
    assertEquals(s.events.includes(`delete:${ID}`), true);
    assertEquals(s.events.at(-1), 'remove:temp-0');
    assertEquals(Array.from(s.key), Array(16).fill(0));
    if (fail === 'delete') assertEquals(error.code, 'rollback_failed');
  });
}

Deno.test('C-2: confirmation receives exact AES key hex, returns summary and cleans work directory', async () => {
  const s = setup();
  const result = await publish(REQUEST, s.deps);
  assertEquals(s.confirmations, ['000102030405060708090a0b0c0d0e0f']);
  assertEquals(result, { assetId: ID, title: 'Lesson', durationS: 31, sizeMb: 2, quota: { used_mb: 12, cap_mb: 100 } });
  assertEquals(s.events.at(-1), 'remove:temp-0');
  assertEquals(Array.from(s.key), Array(16).fill(0));
});

Deno.test('SEC-01: packaging failure wipes key and temp directory before any sign-in', async () => {
  const s = setup({ fail: 'pack' });
  await assertRejects(() => publish(REQUEST, s.deps));
  assertEquals(s.events.includes('sign-in'), false);
  assertEquals(s.events.at(-1), 'remove:temp-0');
  assertEquals(Array.from(s.key), Array(16).fill(0));
});

Deno.test('C-2: failed presigned PUT rolls back reservation without leaking URLs', async () => {
  const s = setup();
  s.deps.storage = new PresignedUpload(() => Promise.resolve(new Uint8Array()), () => Promise.resolve(new Response('SECRET_ERROR', { status: 403 })));
  const error = await assertRejects(() => publish(REQUEST, s.deps), ToolError);
  assertEquals(s.events.includes('upload-urls'), true);
  assertEquals(s.events.includes(`delete:${ID}`), true);
  assertEquals(error.message.includes('SECRET'), false);
  assertEquals(error.message.includes('https://'), false);
});

Deno.test('SEC-01: dry-run keeps output, isolates temporary key and never signs in or uploads', async () => {
  const s = setup();
  const result = await publish({ ...REQUEST, dryRun: true, out: 'offline-output' }, s.deps);
  assertEquals(result, { title: 'Lesson', durationS: 31, sizeMb: 2, output: 'offline-output' });
  assertEquals(s.events.includes('sign-in'), false);
  assertEquals(s.events.includes('upload'), false);
  assertEquals(s.events.includes('remove:offline-output'), false);
  assertEquals(s.events.some((e) => e.startsWith('pack:offline-output:temp-0')), true);
  assertEquals(s.events.at(-1), 'remove:temp-0');
});
