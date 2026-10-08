// Firebase App Check for sensitive Edge Function routes (ADR-008, docs/16 §5):
// video-otp, pdf-url, ai-tutor, register-device. The client sends the token in
// `X-Firebase-AppCheck`. Start in `monitor` mode (log, allow); switch to `enforce` after a week
// of clean logs.
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'npm:jose@6.2.12';

export type AppCheckMode = 'monitor' | 'enforce';

export type AppCheckResult =
  | { ok: true; appId: string }
  | { ok: false; reason: 'missing' | 'invalid' | 'not_configured' };

export type AppCheckConfig = {
  /** Firebase project NUMBER (not the id); unset → App Check is not configured yet. */
  projectNumber: string | undefined;
  mode: AppCheckMode;
  /** Injected in tests; defaults to Firebase's public JWKS. */
  keys?: JWTVerifyGetKey;
};

const FIREBASE_JWKS = 'https://firebaseappcheck.googleapis.com/v1/jwks';
let remoteKeys: JWTVerifyGetKey | undefined;

export function appCheckConfigFromEnv(): AppCheckConfig {
  return {
    projectNumber: Deno.env.get('FIREBASE_PROJECT_NUMBER') || undefined,
    mode: Deno.env.get('APP_CHECK_MODE') === 'enforce' ? 'enforce' : 'monitor',
  };
}

export async function verifyAppCheck(token: string | null | undefined, cfg: AppCheckConfig): Promise<AppCheckResult> {
  if (!cfg.projectNumber) return { ok: false, reason: 'not_configured' };
  if (!token) return { ok: false, reason: 'missing' };
  const keys = cfg.keys ?? (remoteKeys ??= createRemoteJWKSet(new URL(FIREBASE_JWKS)));
  try {
    const { payload } = await jwtVerify(token, keys, {
      algorithms: ['RS256'],
      issuer: `https://firebaseappcheck.googleapis.com/${cfg.projectNumber}`,
      audience: `projects/${cfg.projectNumber}`,
    });
    if (typeof payload.sub !== 'string' || payload.sub === '') return { ok: false, reason: 'invalid' };
    return { ok: true, appId: payload.sub };
  } catch {
    return { ok: false, reason: 'invalid' };
  }
}

/**
 * Route gate. Returns whether to continue. In monitor mode every request continues and failures
 * are only logged; in enforce mode a missing or invalid token stops the request. Until the
 * Firebase project exists (`not_configured`) requests continue in both modes.
 */
export async function appCheckGate(
  req: Request,
  route: string,
  cfg: AppCheckConfig,
  log: (line: string) => void = console.warn,
): Promise<{ allow: boolean; result: AppCheckResult }> {
  const result = await verifyAppCheck(req.headers.get('x-firebase-appcheck'), cfg);
  if (result.ok || result.reason === 'not_configured') return { allow: true, result };
  // Log the reason only — never the token.
  log(`app-check ${cfg.mode} ${route}: ${result.reason}`);
  return { allow: cfg.mode === 'monitor', result };
}
