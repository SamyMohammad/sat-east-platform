import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.19';
import { createApi, parseArgs, readPassword, runCli } from './cli.ts';
import { ToolError } from './publish.ts';

const ID = '40000000-0000-0000-0000-000000000001';
const ARGS = ['publish', '--topic', ID, '--title', ' Lesson ', 'clip.mp4'];

Deno.test('C-2: publish arguments validate UUID, trimmed title, input existence and options', async () => {
  assertEquals(await parseArgs([...ARGS, '--dry-run', '--out', 'offline'], () => Promise.resolve(true)), {
    command: 'publish', topicId: ID, title: 'Lesson', input: 'clip.mp4', dryRun: true, out: 'offline',
  });
  for (const args of [ARGS.map((a) => a === ID ? 'bad' : a), ARGS.map((a) => a === ' Lesson ' ? ' ' : a),
    ARGS.map((a) => a === ' Lesson ' ? 'x'.repeat(121) : a), [...ARGS, '--bad'], ['publish', '--title']]) {
    await assertRejects(() => parseArgs(args, () => Promise.resolve(true)), ToolError);
  }
  await assertRejects(() => parseArgs(ARGS, () => Promise.resolve(false)), ToolError);
});

Deno.test('C-2: quota, list and delete commands parse their exact arguments', async () => {
  assertEquals(await parseArgs(['quota', '--env', 'staging.json']), { command: 'quota', env: 'staging.json' });
  assertEquals(await parseArgs(['list', '--topic', ID]), { command: 'list', topicId: ID });
  assertEquals(await parseArgs(['delete', ID]), { command: 'delete', assetId: ID });
});

Deno.test('SEC-01: dry-run does not load configuration or authenticate and prints its size', async () => {
  const lines: string[] = [];
  const code = await runCli([...ARGS, '--dry-run'], {
    isFile: () => Promise.resolve(true), print: (line) => lines.push(line),
    execute: (args) => { assertEquals(args.command, 'publish'); return Promise.resolve({ title: 'Lesson', durationS: 31, sizeMb: 2, output: 'temp-output' }); },
  });
  assertEquals(code, 0);
  assertEquals(lines.join(' ').includes('2 MB'), true);
});

Deno.test('C-2: CLI runtime failure exits 1 with asset ID, usage failure exits 2, raw errors stay hidden', async () => {
  const lines: string[] = [];
  const deps = { isFile: () => Promise.resolve(true), print: (line: string) => lines.push(line),
    execute: () => Promise.reject(new ToolError('upload_failed', 'Upload failed.', ID)) };
  assertEquals(await runCli(ARGS, deps), 1);
  assertEquals(lines.join(' ').includes(ID), true);
  assertEquals(await runCli(['bad-command'], deps), 2);
  const raw = { ...deps, execute: () => Promise.reject(new Error('SECRET_RAW_KEY')) };
  assertEquals(await runCli(ARGS, raw), 1);
  assertEquals(lines.join(' ').includes('SECRET_RAW_KEY'), false);
});

Deno.test('SEC-01: delete calls the public EF with user JWT and publishable apikey', async () => {
  const calls: { url: string; headers: Headers; body: unknown }[] = [];
  const api = createApi({ rpc: () => Promise.reject(new Error('Unexpected RPC')) },
    { supabaseUrl: 'https://project.test', publishableKey: 'publishable' }, () => Promise.resolve('user-jwt'),
    (input, init) => {
      calls.push({ url: String(input), headers: new Headers(init?.headers), body: JSON.parse(String(init?.body)) });
      return Promise.resolve(new Response('{"ok":true}'));
    });
  await api.delete(ID);
  assertEquals(calls[0].url, 'https://project.test/functions/v1/api/teacher/video-delete');
  assertEquals(calls[0].headers.get('authorization'), 'Bearer user-jwt');
  assertEquals(calls[0].headers.get('apikey'), 'publishable');
  assertEquals(calls[0].body, { asset_id: ID });
});

Deno.test('C-2: API adapter uses exact quota/list/confirm RPC contracts and hides unknown errors', async () => {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  const api = createApi({ rpc: (fn, args) => {
    calls.push({ fn, args });
    return Promise.resolve({ data: fn === 'teacher_video_quota' ? { used_mb: 2, cap_mb: 100 }
      : fn === 'teacher_list_videos' ? [] : { ok: true }, error: null });
  } }, { supabaseUrl: 'https://project.test', publishableKey: 'publishable' }, () => Promise.resolve('jwt'));
  assertEquals(await api.quota(), { used_mb: 2, cap_mb: 100 });
  assertEquals(await api.list(ID), []);
  await api.confirm(ID, '00112233445566778899aabbccddeeff');
  assertEquals(calls, [
    { fn: 'teacher_video_quota', args: {} }, { fn: 'teacher_list_videos', args: { p_topic_id: ID } },
    { fn: 'teacher_confirm_video_asset', args: { p_asset_id: ID, p_key_hex: '00112233445566778899aabbccddeeff' } },
  ]);
  const broken = createApi({ rpc: () => Promise.resolve({ data: null, error: { message: 'SECRET_RAW_RPC' } }) },
    { supabaseUrl: 'https://project.test', publishableKey: 'publishable' }, () => Promise.resolve('jwt'));
  const error = await assertRejects(() => broken.quota(), ToolError);
  assertEquals(error.code, 'internal');
  assertEquals(error.message.includes('SECRET'), false);
});

Deno.test('SEC-01: raw password reading never echoes bytes and restores terminal mode', async () => {
  const mode: boolean[] = [];
  const output: string[] = [];
  const input = [115, 101, 99, 114, 101, 116, 13];
  const password = await readPassword({
    isTerminal: () => true, setRaw: (raw) => mode.push(raw),
    read: (buffer) => { buffer[0] = input.shift()!; return Promise.resolve(1); },
    write: (text) => output.push(text), warn: () => { throw new Error('Unexpected warning'); },
    prompt: () => { throw new Error('Unexpected fallback'); },
  });
  assertEquals(password, 'secret');
  assertEquals(mode, [true, false]);
  assertEquals(output.join('').includes('secret'), false);
});

Deno.test('SEC-01: password fallback warns when raw input is unavailable', async () => {
  const warnings: string[] = [];
  assertEquals(await readPassword({ isTerminal: () => false, setRaw: () => {}, read: () => Promise.resolve(null),
    write: () => {}, warn: (text) => warnings.push(text), prompt: () => 'fallback-password' }), 'fallback-password');
  assertEquals(warnings.length, 1);
  assertEquals(warnings[0].includes('echo'), true);
});
