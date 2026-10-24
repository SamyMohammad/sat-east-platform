import { ToolError } from './publish.ts';

export type R2Config = { accountId: string; accessKeyId: string; secretAccessKey: string; bucket: string };
export type Config = { supabaseUrl: string; publishableKey: string; r2: R2Config };
type Sources = { env: Record<string, string | undefined>; readText(path: string): Promise<string> };

export function parseDotEnv(text: string): Record<string, string> {
  const values: Record<string, string> = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const match = line.match(/^(?:export\s+)?([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/);
    if (!match) throw new ToolError('invalid_config', 'Invalid .env.video assignment.');
    let value = match[2];
    if (value.startsWith('"') || value.startsWith("'")) {
      const quoted = value.match(/^(["'])(.*?)\1\s*(?:#.*)?$/);
      if (!quoted) throw new ToolError('invalid_config', 'Invalid .env.video quoted value.');
      value = quoted[2];
    } else value = value.replace(/\s+#.*$/, '').trim();
    values[match[1]] = value;
  }
  return values;
}

export async function loadConfig(envPath?: string, sources: Sources = {
  env: Deno.env.toObject(), readText: (path) => Deno.readTextFile(path),
}, needsR2 = true): Promise<Config> {
  let fileEnv: Record<string, string> = {};
  if (needsR2) {
    try { fileEnv = parseDotEnv(await sources.readText('.env.video')); }
    catch (error) { if (!(error instanceof Deno.errors.NotFound)) throw new ToolError('invalid_config', 'Unable to read .env.video. Check its format and permissions.'); }
  }
  let client: Record<string, unknown> = {};
  if (envPath) {
    try {
      client = JSON.parse(await sources.readText(envPath));
      if (!client || Array.isArray(client) || typeof client !== 'object') throw new Error();
    } catch { throw new ToolError('invalid_config', 'Unable to read the client environment JSON.'); }
  }
  const required = (name: string, value: unknown): string => {
    if (typeof value !== 'string' || !value.trim()) throw new ToolError('missing_config', `${name} is required.`);
    return value.trim();
  };
  const supabaseUrl = required('SUPABASE_URL', envPath ? client.SUPABASE_URL : sources.env.SUPABASE_URL);
  try {
    const url = new URL(supabaseUrl);
    if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname))) throw new Error();
    if (url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error();
  } catch { throw new ToolError('invalid_config', 'SUPABASE_URL must be an HTTPS project URL (HTTP is allowed for localhost).'); }
  const publishableKey = required('SUPABASE_PUBLISHABLE_KEY', envPath ? client.SUPABASE_PUBLISHABLE_KEY : sources.env.SUPABASE_PUBLISHABLE_KEY);
  const r2 = (name: string) => needsR2 ? required(name, sources.env[name] ?? fileEnv[name]) : '';
  return { supabaseUrl: supabaseUrl.replace(/\/$/, ''), publishableKey,
    r2: { accountId: r2('R2_ACCOUNT_ID'), accessKeyId: r2('R2_ACCESS_KEY_ID'), secretAccessKey: r2('R2_SECRET_ACCESS_KEY'), bucket: r2('R2_BUCKET') } };
}
