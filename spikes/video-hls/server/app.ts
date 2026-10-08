// Spike of the future `api` Edge Function video routes (ADR-002, docs/07 `video-otp`).
//
//   POST /video-otp                 { assetId } → { playlistUrl, expiresAt, watermark }
//   GET  /v/<token>/master.m3u8     master playlist (variant URIs are relative → keep the token)
//   GET  /v/<token>/<name>.m3u8     media playlist, segments rewritten to signed URLs
//   GET  /v/<token>/key             the 16-byte AES-128 key, never cached
//   GET  /s/<token>/<file>.ts       local storage only: the segment itself
//
// SPIKE: the caller names itself in `x-spike-user`. SEC-01 replaces this with verifyAuth +
// has_access_topic (enrolment + access window) and reads keys from private.video_keys.
import { type Context, Hono } from 'npm:hono@4.13.13';
import { cors } from 'npm:hono@4.13.13/cors';
import { rewriteMediaPlaylist } from './playlist.ts';
import { LocalStorage, type VideoStorage } from './storage.ts';
import { signToken, verifyToken } from './token.ts';

export type Deps = {
  storage: VideoStorage;
  /** assetId → 16-byte key. Stand-in for private.video_keys. */
  keys: (assetId: string) => Promise<Uint8Array<ArrayBuffer> | null>;
  secret: string;
  tokenTtlSeconds: number;
  segmentTtlSeconds: number;
  now: () => number; // epoch seconds; injected for tests
};

function fail(c: Context, code: 'not_authenticated' | 'forbidden' | 'invalid_input', status: 400 | 401 | 403 | 404) {
  return c.json({ error: { code, message: code } }, status);
}

const HLS = { 'content-type': 'application/vnd.apple.mpegurl', 'cache-control': 'no-store' };

export function createApp(deps: Deps) {
  const app = new Hono();
  app.use('*', cors({ origin: '*', allowHeaders: ['content-type', 'x-spike-user', 'authorization'] }));

  app.post('/video-otp', async (c) => {
    const user = c.req.header('x-spike-user')?.trim();
    if (!user) return fail(c, 'not_authenticated', 401);
    const body = await c.req.json<{ assetId?: string }>().catch(() => null);
    const assetId = body?.assetId;
    if (!assetId || !/^[A-Za-z0-9_-]+$/.test(assetId)) return fail(c, 'invalid_input', 400);
    // Access check would go here (has_access_topic). Unknown asset → forbidden, so the
    // response does not reveal which asset ids exist.
    if (!(await deps.keys(assetId))) return fail(c, 'forbidden', 403);

    const expiresAt = deps.now() + deps.tokenTtlSeconds;
    const token = await signToken({ k: 'p', a: assetId, u: user, e: expiresAt }, deps.secret);
    const origin = new URL(c.req.url).origin;
    return c.json({
      playlistUrl: `${origin}/v/${token}/master.m3u8`,
      expiresAt,
      // Real version: full_name + phone tail / short id from profiles.
      watermark: { name: user, shortId: (await shortId(user)) },
    });
  });

  app.get('/v/:token/key', async (c) => {
    const p = await verifyToken(c.req.param('token'), deps.secret, deps.now(), 'p');
    if (!p) return fail(c, 'forbidden', 403);
    const key = await deps.keys(p.a);
    if (!key) return fail(c, 'forbidden', 403);
    return c.body(key, 200, { 'content-type': 'application/octet-stream', 'cache-control': 'no-store' });
  });

  app.get('/v/:token/:file{[A-Za-z0-9_-]+\\.m3u8}', async (c) => {
    const p = await verifyToken(c.req.param('token'), deps.secret, deps.now(), 'p');
    if (!p) return fail(c, 'forbidden', 403);
    const file = c.req.param('file');
    const text = await deps.storage.getText(p.a, file);
    if (text === null) return fail(c, 'invalid_input', 404);
    if (file === 'master.m3u8') return c.body(text, 200, HLS);
    const origin = new URL(c.req.url).origin;
    const rewritten = await rewriteMediaPlaylist(
      text, (name) => deps.storage.segmentUrl(p.a, name, deps.segmentTtlSeconds, origin),
    );
    return c.body(rewritten, 200, HLS);
  });

  app.get('/s/:token/:file{[A-Za-z0-9_-]+\\.ts}', async (c) => {
    if (!(deps.storage instanceof LocalStorage)) return c.notFound();
    const file = c.req.param('file');
    const p = await verifyToken(c.req.param('token'), deps.secret, deps.now(), 's');
    if (!p || p.u !== file) return fail(c, 'forbidden', 403);
    const bytes = await deps.storage.readSegment(p.a, file);
    if (!bytes) return fail(c, 'invalid_input', 404);
    return c.body(bytes, 200, { 'content-type': 'video/mp2t', 'cache-control': 'private, max-age=3600' });
  });

  return app;
}

/** First 6 hex chars of SHA-256(user) — a stand-in for the student's short id. */
async function shortId(user: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(user)));
  return Array.from(d.slice(0, 3), (b) => b.toString(16).padStart(2, '0')).join('').toUpperCase();
}
