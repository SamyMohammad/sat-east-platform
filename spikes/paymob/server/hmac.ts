// Paymob HMAC (ADR-003): HMAC-SHA512, hex, over fixed fields joined with no separator.

export type PaymobTransaction = {
  id: number;
  pending: boolean;
  amount_cents: number;
  success: boolean;
  is_auth: boolean;
  is_capture: boolean;
  is_standalone_payment: boolean;
  is_voided: boolean;
  is_refunded: boolean;
  is_3d_secure: boolean;
  integration_id: number;
  has_parent_transaction: boolean;
  created_at: string;
  currency: string;
  error_occured: boolean;
  owner: number;
  order: { id: number; merchant_order_id?: string | null };
  source_data: { pan: string; type: string; sub_type: string };
};

/** String signed for the processed (webhook) callback: `{type: "TRANSACTION", obj}`. */
export function transactionHmacString(o: PaymobTransaction): string {
  return [
    o.amount_cents, o.created_at, o.currency, o.error_occured, o.has_parent_transaction, o.id,
    o.integration_id, o.is_3d_secure, o.is_auth, o.is_capture, o.is_refunded,
    o.is_standalone_payment, o.is_voided, o.order.id, o.owner, o.pending, o.source_data.pan,
    o.source_data.sub_type, o.source_data.type, o.success,
  ].map(String).join('');
}

const REDIRECT_FIELDS = [
  'amount_cents', 'created_at', 'currency', 'error_occured', 'has_parent_transaction', 'id',
  'integration_id', 'is_3d_secure', 'is_auth', 'is_capture', 'is_refunded', 'is_standalone_payment',
  'is_voided', 'order', 'owner', 'pending', 'source_data.pan', 'source_data.sub_type',
  'source_data.type', 'success',
] as const;

/** String signed for the redirect (GET) callback; values arrive as query strings. Null if a field is missing. */
export function redirectHmacString(q: URLSearchParams): string | null {
  const parts: string[] = [];
  for (const f of REDIRECT_FIELDS) {
    const v = q.get(f);
    if (v === null) return null;
    parts.push(v);
  }
  return parts.join('');
}

const enc = new TextEncoder();

async function key(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-512' }, false, ['sign', 'verify'],
  );
}

export async function signHmac(data: string, secret: string): Promise<string> {
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', await key(secret), enc.encode(data)));
  return Array.from(sig, (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Constant-time check of a hex HMAC (crypto.subtle.verify compares in constant time). */
export async function verifyHmac(data: string, hex: string | null | undefined, secret: string): Promise<boolean> {
  if (!hex || !/^[0-9a-fA-F]{128}$/.test(hex)) return false;
  const sig = Uint8Array.from(hex.match(/../g)!, (h) => parseInt(h, 16));
  return await crypto.subtle.verify('HMAC', await key(secret), sig, enc.encode(data));
}
