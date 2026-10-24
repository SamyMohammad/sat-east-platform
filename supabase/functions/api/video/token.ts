// Ported from the HLS spike. Only playback tokens are accepted in production.
export type TokenPayload = {
  k: 'p'; a: string; u: string; t: number; e: number;
  key_ttl_s: number; playlist_ttl_s: number;
};

const enc = new TextEncoder();
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromB64url(s: string): Uint8Array<ArrayBuffer> {
  if (!/^[A-Za-z0-9_-]+$/.test(s)) throw new Error('Invalid token encoding.');
  return Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - s.length % 4) % 4)), (ch) => ch.charCodeAt(0));
}

function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

export async function signToken(payload: TokenPayload, secret: string): Promise<string> {
  const body = b64url(enc.encode(JSON.stringify(payload)));
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(body)));
  return `${body}.${b64url(sig)}`;
}

export async function verifyToken(token: string, secret: string, now: number): Promise<TokenPayload | null> {
  if (token.length > 2048) return null;
  const [body, sig, extra] = token.split('.');
  if (!body || !sig || extra !== undefined) return null;
  try {
    if (!await crypto.subtle.verify('HMAC', await hmacKey(secret), fromB64url(sig), enc.encode(body))) return null;
    const p = JSON.parse(new TextDecoder().decode(fromB64url(body)));
    if (p?.k !== 'p' || typeof p.a !== 'string' || !uuid.test(p.a) || typeof p.u !== 'string' || !p.u
      || !Number.isSafeInteger(p.t) || !Number.isSafeInteger(p.e)
      || !Number.isSafeInteger(p.key_ttl_s) || p.key_ttl_s <= 0
      || !Number.isSafeInteger(p.playlist_ttl_s) || p.playlist_ttl_s <= 0
      || p.e !== p.t + p.playlist_ttl_s || p.t > now || p.e <= now) return null;
    return p;
  } catch {
    return null;
  }
}
