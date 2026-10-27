import { createAdminClient, createContextClient, verifyAuth } from 'npm:@supabase/server@1.9.1/core';
import { appCheckConfigFromEnv } from '../_shared/app_check.ts';
import { captureError, initSentry } from '../_shared/sentry.ts';
import { createApp, type Deps } from './app.ts';
import { R2Storage } from './video/r2.ts';

initSentry('api');

function videoFromEnv(): Deps['video'] {
  // Dashboard pastes can carry a trailing newline/space; R2 then rejects the key length.
  const env = (name: string) => Deno.env.get(name)?.trim();
  const secret = env('VIDEO_TOKEN_SECRET');
  const supabaseUrl = env('SUPABASE_URL');
  const serviceRoleKey = env('SUPABASE_SERVICE_ROLE_KEY');
  const accountId = env('R2_ACCOUNT_ID');
  const accessKeyId = env('R2_ACCESS_KEY_ID');
  const secretAccessKey = env('R2_SECRET_ACCESS_KEY');
  const bucket = env('R2_BUCKET');
  if (!secret || !supabaseUrl || !serviceRoleKey || !accountId || !accessKeyId || !secretAccessKey || !bucket) return undefined;
  return {
    secret, supabaseUrl,
    storage: new R2Storage({ accountId, accessKeyId, secretAccessKey, bucket }),
    now: () => Math.floor(Date.now() / 1000),
    async serviceKey(assetId) {
      const admin = createAdminClient({ env: { url: supabaseUrl, secretKeys: { default: serviceRoleKey } } });
      const { data, error } = await admin.rpc('service_video_key', { p_asset_id: assetId });
      if (error) throw new Error('Video key lookup failed.');
      if (data === null) return null;
      if (typeof data?.key_hex !== 'string' || !/^[a-fA-F0-9]{32}$/.test(data.key_hex)
        || data.r2_prefix !== `videos/${assetId}`) throw new Error('Invalid video key.');
      return {
        key: Uint8Array.from(data.key_hex.match(/../g)!, (hex: string) => parseInt(hex, 16)),
        prefix: data.r2_prefix,
      };
    },
  };
}

const app = createApp({
  appCheck: appCheckConfigFromEnv(),
  reportError: captureError,
  video: videoFromEnv(),
  // Production fails closed; only injected test deps default to wildcard CORS.
  videoAllowedOrigins: (Deno.env.get('VIDEO_ALLOWED_ORIGINS') ?? '').split(',').map((origin) => origin.trim()).filter(Boolean),
  async authenticate(req) {
    const { data: auth, error } = await verifyAuth(req, { auth: 'user' });
    if (error) return null;
    const deviceId = req.headers.get('x-device-id');
    const supabase = createContextClient({
      auth: { token: auth.token, keyName: auth.keyName },
      supabaseOptions: { global: { headers: deviceId === null ? {} : { 'x-device-id': deviceId } } },
    });
    return {
      userId: auth.jwtClaims?.sub,
      rpc: async (fn, args) => {
        const { data, error } = await supabase.rpc(fn, args);
        return { data, error: error ? { message: error.message, code: error.code } : null };
      },
    };
  },
});

export default { fetch: app.fetch };
