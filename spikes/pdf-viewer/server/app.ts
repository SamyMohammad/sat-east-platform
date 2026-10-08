// Spike of the future `api` /pdf-url route + a stand-in for Supabase Storage signed URLs (SEC-02).
//
//   POST /pdf-url        { assetId } → { url, expiresAt, watermark }   (url valid TOKEN_TTL_S)
//   GET  /f/<token>/<assetId>.pdf      the file; supports Range like Storage; 403 after expiry
//
// SPIKE: the caller names itself in `x-spike-user`. The real route checks has_access_topic and
// returns `storage.from('notes').createSignedUrl(path, 300)`.
import { type Context, Hono } from 'npm:hono@4.13.13';
import { cors } from 'npm:hono@4.13.13/cors';
import { signToken, verifyToken } from '../../video-hls/server/token.ts';
import { stampPdf } from './stamp.ts';

export type Deps = {
  /** assetId → original PDF bytes. Stand-in for the private `notes` bucket. */
  files: (assetId: string) => Promise<Uint8Array | null>;
  secret: string;
  tokenTtlSeconds: number;
  /** When true, every served copy carries the student's id inside the PDF (question 6). */
  stamp: boolean;
  now: () => number; // epoch seconds
  log: (line: string) => void;
};

function fail(c: Context, code: 'not_authenticated' | 'forbidden' | 'invalid_input', status: 400 | 401 | 403 | 416) {
  return c.json({ error: { code, message: code } }, status);
}

/** First 6 hex chars of SHA-256(user): the short id shown in the watermark. */
export async function shortId(user: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(user)));
  return Array.from(d.slice(0, 3), (b) => b.toString(16).padStart(2, '0')).join('').toUpperCase();
}

export function createApp(deps: Deps) {
  const app = new Hono();
  // Stamped copies per asset+user, so Range requests see the same bytes.
  const stamped = new Map<string, Uint8Array>();
  app.use('*', cors({
    origin: '*',
    allowHeaders: ['content-type', 'x-spike-user', 'range'],
    exposeHeaders: ['content-length', 'content-range', 'accept-ranges'],
  }));

  app.post('/pdf-url', async (c) => {
    // Percent-encoded: HTTP headers cannot carry Arabic names.
    let user: string | undefined;
    try {
      user = decodeURIComponent(c.req.header('x-spike-user') ?? '').trim();
    } catch {
      user = undefined;
    }
    if (!user) return fail(c, 'not_authenticated', 401);
    const body = await c.req.json<{ assetId?: string }>().catch(() => null);
    const assetId = body?.assetId;
    if (!assetId || !/^[A-Za-z0-9_-]+$/.test(assetId)) return fail(c, 'invalid_input', 400);
    if (!(await deps.files(assetId))) return fail(c, 'forbidden', 403);
    const expiresAt = deps.now() + deps.tokenTtlSeconds;
    const token = await signToken({ k: 'p', a: assetId, u: user, e: expiresAt }, deps.secret);
    return c.json({
      url: `${new URL(c.req.url).origin}/f/${token}/${assetId}.pdf`,
      expiresAt,
      watermark: { name: user, shortId: await shortId(user) },
    });
  });

  app.get('/f/:token/:file{[A-Za-z0-9_-]+\\.pdf}', async (c) => {
    const p = await verifyToken(c.req.param('token'), deps.secret, deps.now(), 'p');
    if (!p || c.req.param('file') !== `${p.a}.pdf`) {
      deps.log(`GET pdf → 403 (expired or bad token)`);
      return fail(c, 'forbidden', 403);
    }
    const original = await deps.files(p.a);
    if (!original) return fail(c, 'forbidden', 403);
    let bytes = original;
    if (deps.stamp) {
      const key = `${p.a}|${p.u}`;
      let s = stamped.get(key);
      if (!s) {
        const t0 = performance.now();
        const id = await shortId(p.u);
        s = await stampPdf(original, `ID ${id}`, `Licensed to student ${id} - personal use only`);
        deps.log(`stamped ${p.a} for ${id} in ${(performance.now() - t0).toFixed(0)} ms`);
        stamped.set(key, s);
      }
      bytes = s;
    }
    const headers: Record<string, string> = {
      'content-type': 'application/pdf',
      'cache-control': 'no-store',
      'accept-ranges': 'bytes',
      // No `content-disposition: attachment`: never offer it as a download.
    };
    const range = c.req.header('range');
    if (range) {
      const m = /^bytes=(\d+)-(\d*)$/.exec(range);
      if (!m) return fail(c, 'invalid_input', 416);
      const start = Number(m[1]);
      const end = m[2] ? Math.min(Number(m[2]), bytes.length - 1) : bytes.length - 1;
      if (start > end) return fail(c, 'invalid_input', 416);
      deps.log(`GET pdf range ${start}-${end} → 206`);
      return c.body(bytes.slice(start, end + 1) as Uint8Array<ArrayBuffer>, 206, {
        ...headers, 'content-range': `bytes ${start}-${end}/${bytes.length}`,
      });
    }
    deps.log(`GET pdf full ${bytes.length} bytes → 200`);
    return c.body(bytes as Uint8Array<ArrayBuffer>, 200, headers);
  });

  return app;
}
