// Stateless playback token: base64url(JSON payload) + "." + base64url(HMAC-SHA256).
// k = kind ('p' playback: playlists + key, 's' segment), a = asset, u = user (or segment file for
// 's'), e = expiry in epoch seconds. The kind stops a segment token from opening the key route.

export type TokenKind = 'p' | 's';
export type TokenPayload = { k: TokenKind; a: string; u: string; e: number };

const enc = new TextEncoder();

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromB64url(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4);
  return Uint8Array.from(atob(b64), (ch) => ch.charCodeAt(0));
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify'],
  );
}

export async function signToken(payload: TokenPayload, secret: string): Promise<string> {
  const body = b64url(enc.encode(JSON.stringify(payload)));
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', await hmacKey(secret), enc.encode(body)));
  return `${body}.${b64url(sig)}`;
}

/** Returns the payload, or null when the token is malformed, tampered with or expired. */
export async function verifyToken(
  token: string, secret: string, nowSeconds: number, kind: TokenKind,
): Promise<TokenPayload | null> {
  const [body, sig, extra] = token.split('.');
  if (!body || !sig || extra !== undefined) return null;
  let ok: boolean;
  try {
    // crypto.subtle.verify compares in constant time.
    ok = await crypto.subtle.verify('HMAC', await hmacKey(secret), fromB64url(sig), enc.encode(body));
  } catch {
    return null;
  }
  if (!ok) return null;
  let payload: TokenPayload;
  try {
    payload = JSON.parse(new TextDecoder().decode(fromB64url(body)));
  } catch {
    return null;
  }
  if (payload?.k !== kind || typeof payload?.a !== 'string' || typeof payload?.u !== 'string' || typeof payload?.e !== 'number') {
    return null;
  }
  return payload.e > nowSeconds ? payload : null;
}
