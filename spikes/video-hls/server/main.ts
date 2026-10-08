// deno run -A spikes/video-hls/server/main.ts
//
// Env: VIDEO_TOKEN_SECRET (required), PORT (8787), KEYS_DIR (folder of <assetId>.key.hex files),
//      STORAGE=local|r2, VIDEOS_DIR (local), R2_ACCOUNT_ID / R2_ACCESS_KEY_ID /
//      R2_SECRET_ACCESS_KEY / R2_BUCKET (r2), TOKEN_TTL_S (300), SEGMENT_TTL_S (14400).
import { join } from 'jsr:@std/path@1.1.4';
import { createApp } from './app.ts';
import { LocalStorage, R2Storage, type VideoStorage } from './storage.ts';

function env(name: string, fallback?: string): string {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined || v === '') throw new Error(`${name} is not set`);
  return v;
}

const secret = env('VIDEO_TOKEN_SECRET');
if (secret.length < 32) throw new Error('VIDEO_TOKEN_SECRET must be at least 32 characters');

const keysDir = env('KEYS_DIR', 'out/videos');
const storage: VideoStorage = env('STORAGE', 'local') === 'r2'
  ? new R2Storage({
    accountId: env('R2_ACCOUNT_ID'),
    accessKeyId: env('R2_ACCESS_KEY_ID'),
    secretAccessKey: env('R2_SECRET_ACCESS_KEY'),
    bucket: env('R2_BUCKET'),
  })
  : new LocalStorage(env('VIDEOS_DIR', keysDir), secret);

async function keys(assetId: string): Promise<Uint8Array<ArrayBuffer> | null> {
  if (!/^[A-Za-z0-9_-]+$/.test(assetId)) return null;
  try {
    const hex = (await Deno.readTextFile(join(keysDir, `${assetId}.key.hex`))).trim();
    if (!/^[0-9a-f]{32}$/.test(hex)) return null;
    return Uint8Array.from(hex.match(/../g)!, (h) => parseInt(h, 16));
  } catch {
    return null;
  }
}

const app = createApp({
  storage,
  keys,
  secret,
  tokenTtlSeconds: Number(env('TOKEN_TTL_S', '300')),
  segmentTtlSeconds: Number(env('SEGMENT_TTL_S', '14400')),
  now: () => Math.floor(Date.now() / 1000),
});

Deno.serve({ port: Number(env('PORT', '8787')), hostname: '0.0.0.0' }, app.fetch);
