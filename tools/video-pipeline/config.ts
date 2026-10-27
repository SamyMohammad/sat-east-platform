import { ToolError } from './publish.ts';

export type Config = { supabaseUrl: string; publishableKey: string };
type Sources = { env: Record<string, string | undefined>; readText(path: string): Promise<string> };

export async function loadConfig(envPath?: string, sources: Sources = {
  env: { SUPABASE_URL: Deno.env.get('SUPABASE_URL'), SUPABASE_PUBLISHABLE_KEY: Deno.env.get('SUPABASE_PUBLISHABLE_KEY') },
  readText: (path) => Deno.readTextFile(path),
}): Promise<Config> {
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
  return { supabaseUrl: supabaseUrl.replace(/\/$/, ''), publishableKey };
}
