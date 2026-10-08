// `api` Edge Function (docs/16 §8): one Hono router for the routes in docs/07 §1.2.
// Business rules stay in Postgres; routes add only what needs a secret or a third party
// (here: App Check). Built from supabase/templates/edge-function.ts.
import { type Context, Hono } from 'npm:hono@4.13.13';
import { type AppCheckConfig, appCheckGate } from '../_shared/app_check.ts';

// Mirror of docs/07 §9 — keep in sync.
const ERROR_CODES = [
  'not_authenticated', 'forbidden', 'invalid_input', 'not_enrolled', 'access_expired',
  'topic_locked', 'attempt_closed', 'deadline_passed', 'device_limit', 'device_revoked',
  'cooldown_active', 'pool_exhausted', 'rate_limited', 'payment_invalid', 'internal',
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
};

export function createApp(deps: Deps) {
  const app = new Hono().basePath('/api');

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
