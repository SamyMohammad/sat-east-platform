// deno test -A supabase/functions/_shared/
import { assertEquals } from 'jsr:@std/assert@1.0.19';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'npm:jose@6.2.12';
import { type AppCheckConfig, appCheckGate, verifyAppCheck } from './app_check.ts';
import { captureError, initSentry } from './sentry.ts';

const PROJECT = '123456789012';
const { publicKey, privateKey } = await generateKeyPair('RS256');
const { privateKey: otherKey } = await generateKeyPair('RS256');
const jwk = { ...(await exportJWK(publicKey)), kid: 'k1', alg: 'RS256' };
const keys = createLocalJWKSet({ keys: [jwk] });
const cfg = (mode: AppCheckConfig['mode'] = 'monitor'): AppCheckConfig => ({ projectNumber: PROJECT, mode, keys });

async function token(o: { iss?: string; aud?: string[]; exp?: string; key?: CryptoKey; sub?: string } = {}) {
  return await new SignJWT({})
    .setProtectedHeader({ alg: 'RS256', kid: 'k1', typ: 'JWT' })
    .setIssuer(o.iss ?? `https://firebaseappcheck.googleapis.com/${PROJECT}`)
    .setAudience(o.aud ?? [`projects/${PROJECT}`, 'projects/sat-east'])
    .setSubject(o.sub ?? '1:123456789012:web:abc')
    .setIssuedAt()
    .setExpirationTime(o.exp ?? '1h')
    .sign(o.key ?? privateKey);
}

function req(t?: string) {
  return new Request('http://local/video-otp', { headers: t ? { 'x-firebase-appcheck': t } : {} });
}

Deno.test('F-5 app check: valid token → ok with the app id', async () => {
  assertEquals(await verifyAppCheck(await token(), cfg()), { ok: true, appId: '1:123456789012:web:abc' });
});

Deno.test('F-5 app check: wrong issuer, audience, signature or expired → invalid', async () => {
  for (const t of [
    await token({ iss: 'https://firebaseappcheck.googleapis.com/999' }),
    await token({ aud: ['projects/999'] }),
    await token({ key: otherKey }),
    await token({ exp: '-1m' }),
    'not-a-jwt',
  ]) {
    assertEquals(await verifyAppCheck(t, cfg()), { ok: false, reason: 'invalid' });
  }
});

Deno.test('F-5 app check: missing token / no Firebase project yet', async () => {
  assertEquals(await verifyAppCheck(null, cfg()), { ok: false, reason: 'missing' });
  assertEquals(await verifyAppCheck(await token(), { projectNumber: undefined, mode: 'enforce' }), {
    ok: false, reason: 'not_configured',
  });
});

Deno.test('F-5 app check gate: monitor allows and logs, enforce blocks', async () => {
  const logs: string[] = [];
  const monitor = await appCheckGate(req(), 'video-otp', cfg('monitor'), (l) => logs.push(l));
  assertEquals(monitor.allow, true);
  const enforce = await appCheckGate(req('bad'), 'video-otp', cfg('enforce'), (l) => logs.push(l));
  assertEquals(enforce.allow, false);
  assertEquals(logs, ['app-check monitor video-otp: missing', 'app-check enforce video-otp: invalid']);
  const ok = await appCheckGate(req(await token()), 'video-otp', cfg('enforce'), (l) => logs.push(l));
  assertEquals(ok.allow, true);
  assertEquals(logs.length, 2, 'a valid token is not logged');
});

Deno.test('F-5 app check gate: not configured → allowed in enforce mode, nothing logged', async () => {
  const logs: string[] = [];
  const r = await appCheckGate(req(), 'pdf-url', { projectNumber: undefined, mode: 'enforce' }, (l) => logs.push(l));
  assertEquals(r.allow, true);
  assertEquals(logs, []);
});

Deno.test('F-5 sentry: off without a DSN, and capture is then a no-op', async () => {
  assertEquals(initSentry('api', ''), false);
  await captureError(new Error('boom'), { route: '/x' });
});
