import { join } from 'jsr:@std/path@1.1.4';
import { loadConfig, type Config } from './config.ts';
import { packVideo, probeDuration } from './ffmpeg.ts';
import { publish, type CreateResult, type PublishRequest, type PublishSummary, type Quota, ToolError, type VideoApi, type VideoFile } from './publish.ts';
import { PresignedUpload } from './r2_upload.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
type Command = ({ command: 'publish'; env?: string } & PublishRequest)
  | { command: 'quota'; env?: string } | { command: 'list'; topicId: string; env?: string }
  | { command: 'delete'; assetId: string; env?: string };
type IsFile = (path: string) => Promise<boolean>;

const isFile: IsFile = async (path) => { try { return (await Deno.stat(path)).isFile; } catch { return false; } };
function usage(): never { throw new ToolError('usage', 'Usage: publish --topic <uuid> [--subtopic <uuid>] --title <title> [--env <json>] [--dry-run] [--out <dir>] <file> | quota [--env <json>] | list --topic <uuid> [--env <json>] | delete <uuid> [--env <json>]'); }

export async function parseArgs(args: string[], exists: IsFile = isFile): Promise<Command> {
  const [command, ...rest] = args;
  if (!['publish', 'quota', 'list', 'delete'].includes(command)) usage();
  const flags: Record<string, string> = {};
  const positional: string[] = [];
  let dryRun = false;
  let positionalOnly = false;
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (arg === '--' && !positionalOnly) { positionalOnly = true; continue; }
    if (positionalOnly || !arg.startsWith('--')) { positional.push(arg); continue; }
    if (arg === '--dry-run' && command === 'publish' && !dryRun) { dryRun = true; continue; }
    const allowed = command === 'publish' ? ['--topic', '--subtopic', '--title', '--env', '--out'] : command === 'list' ? ['--topic', '--env'] : ['--env'];
    if (!allowed.includes(arg) || arg in flags || !rest[i + 1] || rest[i + 1].startsWith('--')) usage();
    flags[arg] = rest[++i];
  }
  const env = flags['--env'] ? { env: flags['--env'] } : {};
  if (command === 'quota' && positional.length === 0) return { command, ...env };
  if (command === 'delete' && positional.length === 1 && UUID.test(positional[0])) return { command, assetId: positional[0].toLowerCase(), ...env };
  if (!UUID.test(flags['--topic'] ?? '')) usage();
  if (command === 'list' && positional.length === 0) return { command, topicId: flags['--topic'].toLowerCase(), ...env };
  const title = flags['--title']?.trim();
  if (command !== 'publish' || positional.length !== 1 || !title || Array.from(title).length > 120
    || (flags['--subtopic'] !== undefined && !UUID.test(flags['--subtopic'])) || (flags['--out'] && !dryRun)) usage();
  if (!await exists(positional[0])) throw new ToolError('usage', 'Input file does not exist or is not a readable file.');
  return { command, topicId: flags['--topic'].toLowerCase(), title, input: positional[0], dryRun, ...env,
    ...(flags['--subtopic'] ? { subtopicId: flags['--subtopic'].toLowerCase() } : {}), ...(flags['--out'] ? { out: flags['--out'] } : {}) };
}

type PasswordIO = {
  isTerminal(): boolean;
  setRaw(raw: boolean): void;
  read(buffer: Uint8Array): Promise<number | null>;
  write(text: string): void;
  warn(text: string): void;
  prompt(text: string): string | null;
};

export async function readPassword(io: PasswordIO = {
  isTerminal: () => Deno.stdin.isTerminal(), setRaw: (raw) => Deno.stdin.setRaw(raw),
  read: (buffer) => Deno.stdin.read(buffer), write: (text) => { Deno.stdout.writeSync(new TextEncoder().encode(text)); },
  warn: console.warn, prompt,
}): Promise<string> {
  try {
    if (!io.isTerminal()) throw new Error();
    io.setRaw(true);
  } catch {
    io.warn('Password hiding is unavailable; the following prompt may echo your password.');
    return io.prompt('Password:') ?? '';
  }
  const bytes: number[] = [];
  try {
    io.write('Password: ');
    const byte = new Uint8Array(1);
    while (await io.read(byte) !== null) {
      const value = byte[0];
      if (value === 13 || value === 10) return new TextDecoder().decode(Uint8Array.from(bytes));
      if (value === 3 || value === 4) throw new ToolError('cancelled', 'Sign-in cancelled.');
      if (value === 8 || value === 127) {
        while (bytes.length && (bytes.at(-1)! & 0xc0) === 0x80) bytes.pop();
        bytes.pop();
      } else bytes.push(value);
    }
    throw new ToolError('cancelled', 'Sign-in cancelled.');
  } finally {
    bytes.fill(0);
    io.setRaw(false);
    io.write('\n');
  }
}

const ERROR_MESSAGES: Record<string, string> = {
  forbidden: 'This operation requires a teacher account.', not_authenticated: 'Sign in again.',
  invalid_credentials: 'Email or password was not accepted.', invalid_input: 'The server rejected the video details.',
  quota_exceeded: 'Video storage quota exceeded.', rate_limited: 'Too many requests. Try again later.',
  internal: 'The server operation failed. Try again.',
};
type RpcClient = { rpc(fn: string, args: Record<string, unknown>): Promise<{ data: unknown; error: { message: string } | null }> };

export function createApi(client: RpcClient, config: Pick<Config, 'supabaseUrl' | 'publishableKey'>,
  token: () => Promise<string>, request: typeof fetch = fetch): VideoApi {
  const rpc = async (fn: string, args: Record<string, unknown> = {}): Promise<unknown> => {
    const { data, error } = await client.rpc(fn, args);
    if (error) {
      const code = Object.hasOwn(ERROR_MESSAGES, error.message) ? error.message : 'internal';
      throw new ToolError(code, ERROR_MESSAGES[code]);
    }
    return data;
  };
  const validQuota = (data: unknown): data is Quota => {
    const q = data as Quota | null;
    return !!q && Number.isSafeInteger(q.used_mb) && q.used_mb >= 0 && Number.isSafeInteger(q.cap_mb) && q.cap_mb >= 0;
  };
  return {
    async quota() { const data = await rpc('teacher_video_quota'); if (!validQuota(data)) throw new ToolError('internal', 'Invalid quota response.'); return data; },
    async create(args) {
      const data = await rpc('teacher_create_video_asset', args) as CreateResult | null;
      if (data?.ok === true && typeof data.asset_id === 'string' && UUID.test(data.asset_id)) return data;
      if (data?.ok === false && data.error === 'quota_exceeded' && validQuota(data)) return data;
      throw new ToolError('internal', 'Invalid reservation response.');
    },
    async confirm(id, hex) {
      const data = await rpc('teacher_confirm_video_asset', { p_asset_id: id, p_key_hex: hex }) as { ok?: unknown } | null;
      if (data?.ok !== true) throw new ToolError('internal', 'Video confirmation failed.');
    },
    async list(id) { const data = await rpc('teacher_list_videos', { p_topic_id: id }); if (!Array.isArray(data)) throw new ToolError('internal', 'Invalid video list response.'); return data; },
    async uploadUrls(id, files) {
      const res = await request(`${config.supabaseUrl}/functions/v1/api/teacher/video-upload-urls`, {
        method: 'POST', headers: { authorization: `Bearer ${await token()}`, apikey: config.publishableKey, 'content-type': 'application/json' },
        body: JSON.stringify({ asset_id: id, files }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        const value = data?.error?.code;
        const code = typeof value === 'string' && Object.hasOwn(ERROR_MESSAGES, value) ? value : 'internal';
        throw new ToolError(code, ERROR_MESSAGES[code]);
      }
      if (!data?.urls || typeof data.urls !== 'object' || Array.isArray(data.urls)
        || Object.keys(data.urls).length !== files.length || !Number.isSafeInteger(data.expires_in) || data.expires_in <= 0) {
        throw new ToolError('internal', 'Invalid upload URL response.');
      }
      for (const file of files) {
        try {
          const url = new URL(data.urls[file]);
          if (!Object.hasOwn(data.urls, file) || url.protocol !== 'https:' || url.username || url.password) throw new Error();
        } catch { throw new ToolError('internal', 'Invalid upload URL response.'); }
      }
      return data.urls;
    },
    async delete(id) {
      const res = await request(`${config.supabaseUrl}/functions/v1/api/teacher/video-delete`, {
        method: 'POST', headers: { authorization: `Bearer ${await token()}`, apikey: config.publishableKey, 'content-type': 'application/json' },
        body: JSON.stringify({ asset_id: id }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok || data?.ok !== true) {
        const value = data?.error?.code;
        const code = typeof value === 'string' && Object.hasOwn(ERROR_MESSAGES, value) ? value : 'internal';
        throw new ToolError(code, ERROR_MESSAGES[code]);
      }
    },
  };
}

async function signIn(config: Config): Promise<VideoApi> {
  const email = prompt('Teacher email:')?.trim();
  if (!email) throw new ToolError('cancelled', 'Sign-in cancelled.');
  const password = await readPassword();
  const { createClient } = await import('npm:@supabase/supabase-js@2.118.0');
  const client = createClient(config.supabaseUrl, config.publishableKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new ToolError('invalid_credentials', ERROR_MESSAGES.invalid_credentials);
  return createApi({ rpc: async (fn, args) => { const { data, error } = await client.rpc(fn, args); return { data, error }; } }, config, async () => {
    const { data, error } = await client.auth.getSession();
    if (error || !data.session) throw new ToolError('not_authenticated', ERROR_MESSAGES.not_authenticated);
    return data.session.access_token;
  });
}

const fileSystem = {
  tempDir: () => Deno.makeTempDir({ prefix: 'video-publish-' }),
  async prepareOutput(dir: string) {
    await Deno.mkdir(dir, { recursive: true });
    for await (const _entry of Deno.readDir(dir)) throw new ToolError('output_not_empty', 'Output directory must be empty. Choose a new --out directory.');
  },
  async files(dir: string): Promise<VideoFile[]> {
    const files: VideoFile[] = [];
    for await (const entry of Deno.readDir(dir)) {
      if (!entry.isFile || !/^(?:master|540p)\.m3u8$|^540p_\d+\.ts$/.test(entry.name)) throw new ToolError('invalid_output', 'Unexpected packaged video file.');
      const path = join(dir, entry.name);
      files.push({ name: entry.name, path, bytes: (await Deno.stat(path)).size });
    }
    return files.sort((a, b) => a.name.localeCompare(b.name));
  },
  remove: (dir: string) => Deno.remove(dir, { recursive: true }),
};

async function execute(command: Command): Promise<unknown> {
  if (command.command === 'publish' && command.dryRun) {
    return publish(command, { probe: probeDuration, pack: packVideo, fs: fileSystem,
      api: () => { throw new Error('Offline.'); }, storage: { upload: () => { throw new Error('Offline.'); } } });
  }
  const config = await loadConfig(command.env);
  if (command.command === 'publish') return publish(command, { probe: probeDuration, pack: packVideo, fs: fileSystem,
    api: () => signIn(config), storage: new PresignedUpload() });
  const api = await signIn(config);
  if (command.command === 'quota') return api.quota();
  if (command.command === 'list') return api.list(command.topicId);
  await api.delete(command.assetId);
  return { deleted: command.assetId };
}

export async function runCli(args: string[], deps: { isFile: IsFile; print(line: string): void; execute(command: Command): Promise<unknown> } = {
  isFile, print: console.log, execute,
}): Promise<number> {
  try {
    const command = await parseArgs(args, deps.isFile);
    const result = await deps.execute(command);
    if (command.command === 'publish') {
      const summary = result as PublishSummary;
      deps.print(`Title: ${summary.title}\nDuration: ${summary.durationS} s\nSize: ${summary.sizeMb} MB`);
      if ('assetId' in summary) deps.print(`Asset ID: ${summary.assetId}\nQuota: ${summary.quota.used_mb} / ${summary.quota.cap_mb} MB`);
      else deps.print(`Dry-run output: ${summary.output}`);
    } else deps.print(JSON.stringify(result, null, 2));
    return 0;
  } catch (error) {
    if (error instanceof ToolError) {
      deps.print(`${error.code}: ${error.message}${error.assetId ? `\nAsset ID: ${error.assetId}` : ''}`);
      return error.code === 'usage' ? 2 : 1;
    }
    deps.print('runtime_failure: Operation failed. Check configuration, connectivity and file permissions.');
    return 1;
  }
}

if (import.meta.main) Deno.exit(await runCli(Deno.args));
