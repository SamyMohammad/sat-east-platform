// R1c: mint HS256 JWTs for the load users created by seed_users.sql.
// Usage: STAGING_JWT_SECRET=... LOAD_USERS=300 node scripts/load/mint_tokens.mjs [out.json]
// Writes a JSON array of tokens (default tokens.json). Never prints tokens or the secret.
import { createHmac } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const TTL_SECONDS = 2 * 60 * 60;
const ID_PREFIX = '00000000-0000-4000-8a0d-';

const b64url = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');

/** Deterministic id for load user n; must match scripts/load/seed_users.sql. */
export function userIdFor(n) {
  return `${ID_PREFIX}${String(n).padStart(12, '0')}`;
}

/** Mint one HS256 JWT for `sub`. `nowSec` is injected so tests are deterministic. */
export function mintToken(secret, sub, nowSec) {
  if (!secret) throw new Error('JWT secret is empty');
  const n = Number.parseInt(sub.slice(ID_PREFIX.length), 10);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    sub,
    role: 'authenticated',
    aud: 'authenticated',
    iat: nowSec,
    exp: nowSec + TTL_SECONDS,
    email: `load-${n}@load.test`,
  };
  const signingInput = `${b64url(header)}.${b64url(payload)}`;
  const sig = createHmac('sha256', secret).update(signingInput).digest('base64url');
  return `${signingInput}.${sig}`;
}

/** Tokens for load users 1..count. */
export function buildTokens(secret, count, nowSec) {
  if (!Number.isInteger(count) || count < 1) {
    throw new Error('LOAD_USERS must be a positive integer');
  }
  return Array.from({ length: count }, (_, i) => mintToken(secret, userIdFor(i + 1), nowSec));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const secret = process.env.STAGING_JWT_SECRET;
  if (!secret) {
    console.error('STAGING_JWT_SECRET is not set');
    process.exit(1);
  }
  const count = Number(process.env.LOAD_USERS);
  const out = process.argv[2] ?? 'tokens.json';
  const tokens = buildTokens(secret, count, Math.floor(Date.now() / 1000));
  writeFileSync(out, JSON.stringify(tokens), { mode: 0o600 });
  console.log(`wrote ${tokens.length} tokens to ${out}`);
}
