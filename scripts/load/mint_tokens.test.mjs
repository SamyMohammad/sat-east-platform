// R1c: unit tests for mintToken / userIdFor (fixed vector, HMAC verified with node:crypto).
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { mintToken, userIdFor, buildTokens } from './mint_tokens.mjs';

const SECRET = 'test-secret-not-real';
const SUB = '00000000-0000-4000-8a0d-000000000001';
const NOW = 1_800_000_000;

const b64urlJson = (s) => JSON.parse(Buffer.from(s, 'base64url').toString('utf8'));

test('mintToken produces a 3-part HS256 JWT', () => {
  const token = mintToken(SECRET, SUB, NOW);
  const parts = token.split('.');
  assert.equal(parts.length, 3);
  assert.deepEqual(b64urlJson(parts[0]), { alg: 'HS256', typ: 'JWT' });
});

test('mintToken payload carries the expected claims', () => {
  const [, payload] = mintToken(SECRET, SUB, NOW).split('.');
  const claims = b64urlJson(payload);
  assert.equal(claims.sub, SUB);
  assert.equal(claims.role, 'authenticated');
  assert.equal(claims.aud, 'authenticated');
  assert.equal(claims.iat, NOW);
  assert.equal(claims.exp, NOW + 2 * 60 * 60);
  assert.equal(claims.email, 'load-1@load.test');
});

test('mintToken signature verifies with HMAC-SHA256 over header.payload', () => {
  const [h, p, sig] = mintToken(SECRET, SUB, NOW).split('.');
  const expected = createHmac('sha256', SECRET).update(`${h}.${p}`).digest('base64url');
  assert.equal(sig, expected);
});

test('mintToken is deterministic and secret-dependent', () => {
  assert.equal(mintToken(SECRET, SUB, NOW), mintToken(SECRET, SUB, NOW));
  assert.notEqual(mintToken(SECRET, SUB, NOW), mintToken('other', SUB, NOW));
});

test('mintToken rejects an empty secret', () => {
  assert.throws(() => mintToken('', SUB, NOW), /secret/i);
});

test('userIdFor matches the seed_users.sql id pattern', () => {
  assert.equal(userIdFor(1), '00000000-0000-4000-8a0d-000000000001');
  assert.equal(userIdFor(300), '00000000-0000-4000-8a0d-000000000300');
});

test('buildTokens returns n tokens for users 1..n', () => {
  const tokens = buildTokens(SECRET, 3, NOW);
  assert.equal(tokens.length, 3);
  const subs = tokens.map((t) => b64urlJson(t.split('.')[1]).sub);
  assert.deepEqual(subs, [userIdFor(1), userIdFor(2), userIdFor(3)]);
});

test('buildTokens rejects a bad user count', () => {
  assert.throws(() => buildTokens(SECRET, 0, NOW), /LOAD_USERS/);
  assert.throws(() => buildTokens(SECRET, 1.5, NOW), /LOAD_USERS/);
});
