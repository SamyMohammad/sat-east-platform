// `api` Edge Function (docs/16 §8): one Hono router for the routes in docs/07 §1.2.
// Business rules stay in Postgres; routes add only what needs a secret or a third party
// (here: App Check). Built from supabase/templates/edge-function.ts.
import { type Context, Hono } from 'npm:hono@4.13.13';
import { cors } from 'npm:hono@4.13.13/cors';
import { type AppCheckConfig, appCheckGate } from '../_shared/app_check.ts';
import { rewriteMediaPlaylist } from './video/playlist.ts';
import type { VideoStorage } from './video/r2.ts';
import { signToken, verifyToken } from './video/token.ts';

// Mirror of docs/07 §9 — keep in sync.
const ERROR_CODES = [
  'not_authenticated', 'forbidden', 'invalid_input', 'not_enrolled', 'access_expired',
  'topic_locked', 'attempt_closed', 'deadline_passed', 'device_limit', 'device_revoked',
  'cooldown_active', 'pool_exhausted', 'rate_limited', 'payment_invalid', 'internal', 'video_needed',
] as const;
type ErrorCode = (typeof ERROR_CODES)[number];

function isErrorCode(value: string): value is ErrorCode {
  return (ERROR_CODES as readonly string[]).includes(value);
}

function fail(c: Context, code: ErrorCode, message: string) {
  const status = code === 'not_authenticated' ? 401
    : code === 'forbidden' ? 403
    : code === 'internal' ? 500
    : 400;
  return c.json({ error: { code, message } }, status);
}

/** The verified caller and a way to call an RPC as them (auth.uid() + RLS apply). */
export type Caller = {
  userId: string | undefined;
  rpc: (fn: string, args: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string; code?: string } | null }>;
};

export type Deps = {
  /** null → not signed in. */
  authenticate: (req: Request) => Promise<Caller | null>;
  appCheck: AppCheckConfig;
  reportError: (error: unknown, context: { route: string; userId?: string; code?: string }) => Promise<void>;
  log?: (line: string) => void;
  videoAllowedOrigins?: string[];
  /** Undefined when video secrets are unavailable; other routes remain usable. */
  video?: {
    secret: string;
    supabaseUrl: string;
    storage: VideoStorage;
    serviceKey: (assetId: string) => Promise<{ key: Uint8Array<ArrayBuffer>; prefix: string } | null>;
    now: () => number;
  };
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HLS = { 'content-type': 'application/vnd.apple.mpegurl', 'cache-control': 'no-store' };

async function assetId(c: Context): Promise<string | null> {
  const body = await c.req.json().catch(() => null);
  return typeof body?.asset_id === 'string' && UUID.test(body.asset_id) ? body.asset_id.toLowerCase() : null;
}

function rpcFailure(c: Context, error: { message: string }) {
  return isErrorCode(error.message) ? fail(c, error.message, error.message)
    : fail(c, 'internal', 'Something went wrong.');
}

export function createApp(deps: Deps) {
  const app = new Hono().basePath('/api');
  const videoCors = cors({
    origin: deps.videoAllowedOrigins ?? '*',
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    allowHeaders: ['authorization', 'content-type', 'x-client-info', 'apikey', 'x-firebase-appcheck', 'x-device-id'],
  });
  app.use('/video-otp', videoCors);
  app.use('/v/*', videoCors);
  app.use('/teacher/*', videoCors);
  app.use('/v/*', async (c, next) => {
    c.header('cache-control', 'no-store');
    await next();
  });

  // Never forward raw dependency errors: they may contain signed URLs or key data.
  const videoRoute = (route: string, handler: (c: Context) => Promise<Response>) => async (c: Context) => {
    try {
      return await handler(c);
    } catch {
      await deps.reportError(new Error('Video request failed.'), { route });
      return fail(c, 'internal', 'Something went wrong.');
    }
  };

  app.post('/video-otp', videoRoute('video-otp', async (c) => {
    const caller = await deps.authenticate(c.req.raw);
    if (!caller) return fail(c, 'not_authenticated', 'Sign in required.');
    const gate = await appCheckGate(c.req.raw, 'video-otp', deps.appCheck, deps.log);
    if (!gate.allow) return fail(c, 'forbidden', 'App verification failed.');
    const video = deps.video;
    if (!video) return fail(c, 'internal', 'Video is unavailable.');
    const id = await assetId(c);
    if (!id) return fail(c, 'invalid_input', 'asset_id is required.');
    const { data, error } = await caller.rpc('video_playback_grant', { p_asset_id: id });
    if (error) return rpcFailure(c, error);
    if (!data || typeof data !== 'object') throw new Error('Invalid grant.');
    const grant = data as Record<string, unknown>;
    if (grant.ok === false) {
      return typeof grant.error === 'string' ? rpcFailure(c, { message: grant.error })
        : fail(c, 'internal', 'Something went wrong.');
    }
    if (grant.ok !== true || !Number.isSafeInteger(grant.resume_s) || (grant.resume_s as number) < 0) throw new Error('Invalid grant.');
    if (grant.provider === 'youtube') {
      if (typeof grant.youtube_id !== 'string' || !/^[A-Za-z0-9_-]{11}$/.test(grant.youtube_id)) throw new Error('Invalid grant.');
      return c.json({ provider: 'youtube', youtube_id: grant.youtube_id, resume_s: grant.resume_s });
    }
    if (grant.provider !== 'r2_hls' || grant.asset_id !== id || typeof grant.user_id !== 'string' || grant.user_id !== caller.userId
      || !Number.isSafeInteger(grant.key_ttl_s) || (grant.key_ttl_s as number) <= 0
      || !Number.isSafeInteger(grant.playlist_ttl_s) || (grant.playlist_ttl_s as number) <= 0) throw new Error('Invalid grant.');
    const watermark = grant.watermark as { name?: unknown; short_id?: unknown } | null;
    if (!watermark || (watermark.name !== null && typeof watermark.name !== 'string') || typeof watermark.short_id !== 'string') throw new Error('Invalid grant.');
    const t = video.now();
    const e = t + (grant.playlist_ttl_s as number);
    const token = await signToken({ k: 'p', a: id, u: grant.user_id, t, e,
      key_ttl_s: grant.key_ttl_s as number, playlist_ttl_s: grant.playlist_ttl_s as number }, video.secret);
    return c.json({ provider: 'r2_hls',
      hls_url: `${video.supabaseUrl.replace(/\/$/, '')}/functions/v1/api/v/${token}/master.m3u8`,
      expires_at: e, watermark: { name: watermark.name, short_id: watermark.short_id }, resume_s: grant.resume_s });
  }));

  app.get('/v/:token/key', videoRoute('video-key', async (c) => {
    const video = deps.video;
    if (!video) return fail(c, 'internal', 'Video is unavailable.');
    const now = video.now();
    const p = await verifyToken(c.req.param('token') ?? '', video.secret, now);
    if (!p || now - p.t > p.key_ttl_s) return fail(c, 'forbidden', 'Playback expired.');
    const result = await video.serviceKey(p.a);
    if (!result) return fail(c, 'forbidden', 'Playback unavailable.');
    if (result.key.length !== 16 || result.prefix !== `videos/${p.a}`) throw new Error('Invalid key data.');
    return c.body(result.key, 200, { 'content-type': 'application/octet-stream', 'cache-control': 'no-store' });
  }));

  app.get('/v/:token/:file', videoRoute('video-playlist', async (c) => {
    const file = c.req.param('file') ?? '';
    if (!/^[A-Za-z0-9_-]+\.m3u8$/.test(file)) return c.notFound();
    const video = deps.video;
    if (!video) return fail(c, 'internal', 'Video is unavailable.');
    const p = await verifyToken(c.req.param('token') ?? '', video.secret, video.now());
    if (!p) return fail(c, 'forbidden', 'Playback expired.');
    const prefix = `videos/${p.a}`;
    const text = await video.storage.getText(prefix, file);
    if (text === null) return c.notFound();
    if (file === 'master.m3u8') return c.body(text, 200, HLS);
    return c.body(await rewriteMediaPlaylist(text, (name) => video.storage.segmentUrl(prefix, name, p.playlist_ttl_s)), 200, HLS);
  }));

  app.post('/teacher/video-delete', videoRoute('teacher/video-delete', async (c) => {
    const caller = await deps.authenticate(c.req.raw);
    if (!caller) return fail(c, 'not_authenticated', 'Sign in required.');
    const video = deps.video;
    if (!video) return fail(c, 'internal', 'Video is unavailable.');
    const id = await assetId(c);
    if (!id) return fail(c, 'invalid_input', 'asset_id is required.');
    const prefixResult = await caller.rpc('teacher_video_prefix', { p_asset_id: id });
    if (prefixResult.error) return rpcFailure(c, prefixResult.error);
    const data = prefixResult.data as { provider?: unknown; r2_prefix?: unknown } | null;
    if (data?.provider === 'r2_hls' && data.r2_prefix === `videos/${id}`) {
      const prefix = `${data.r2_prefix}/`;
      const keys = await video.storage.list(prefix);
      if (keys.some((key) => !key.startsWith(prefix))) throw new Error('Invalid deletion prefix.');
      await video.storage.delete(keys);
    } else if (data?.provider !== 'youtube' || data.r2_prefix !== null) {
      throw new Error('Invalid deletion prefix.');
    }
    const { data: result, error } = await caller.rpc('teacher_delete_video', { p_asset_id: id });
    return error ? rpcFailure(c, error) : c.json(result);
  }));

  // AUTH-04 (docs/07 §8): App Check, then the register_device RPC as the user.
  app.post('/register-device', async (c) => {
    const caller = await deps.authenticate(c.req.raw);
    if (!caller) return fail(c, 'not_authenticated', 'Sign in required.');

    const gate = await appCheckGate(c.req.raw, 'register-device', deps.appCheck, deps.log);
    if (!gate.allow) return fail(c, 'forbidden', 'App verification failed.');

    const body = await c.req.json<{ fingerprint?: unknown; platform?: unknown; label?: unknown }>()
      .catch(() => null);
    if (typeof body?.fingerprint !== 'string') return fail(c, 'invalid_input', 'fingerprint is required.');
    const platform = typeof body.platform === 'string' ? body.platform : null;
    const label = typeof body.label === 'string' ? body.label : null;

    const { data, error } = await caller.rpc('register_device', {
      p_fingerprint: body.fingerprint, p_platform: platform, p_label: label,
    });
    if (error) {
      if (isErrorCode(error.message)) return fail(c, error.message, error.message);
      // Postgres error code only — never tokens or PII.
      console.error('api/register-device rpc failed', error.code);
      await deps.reportError(new Error(`rpc failed: ${error.code}`), {
        route: 'register-device', userId: caller.userId, code: error.code,
      });
      return fail(c, 'internal', 'Something went wrong.');
    }
    // { status: 'ok', device_id } or { status: 'limit_reached', devices, changes_left }
    return c.json(data);
  });

  return app;
}
