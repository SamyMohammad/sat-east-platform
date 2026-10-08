// Mock Paymob for tests and the sandbox e2e: intention API + a fake hosted checkout page that
// sends a correctly signed webhook, then redirects the browser like Paymob does.
//
//   deno run -A spikes/paymob/server/mock_paymob.ts   (env: MOCK_PORT=8791, PAYMOB_HMAC_SECRET)
import { Hono } from 'npm:hono@4.13.13';
import { type PaymobTransaction, redirectHmacString, signHmac, transactionHmacString } from './hmac.ts';
import type { IntentionRequest } from './paymob.ts';

export const MOCK_SECRET_KEY = 'mock_secret_key';
export const MOCK_OWNER = 302852;

let seq = 1000;

export function buildTransaction(
  gatewayOrderId: number, amountCents: number, currency: string, integrationId: number,
  overrides: Partial<PaymobTransaction> = {},
): PaymobTransaction {
  return {
    id: ++seq + 190_000_000, pending: false, amount_cents: amountCents, success: true,
    is_auth: false, is_capture: false, is_standalone_payment: true, is_voided: false,
    is_refunded: false, is_3d_secure: true, integration_id: integrationId,
    has_parent_transaction: false, created_at: '2026-10-08T15:01:02.123456', currency,
    error_occured: false, owner: MOCK_OWNER, order: { id: gatewayOrderId },
    source_data: { pan: '2346', type: 'card', sub_type: 'MasterCard' },
    ...overrides,
  };
}

/** Webhook URL (with ?hmac) and body for a transaction, signed like Paymob signs it. */
export async function signedWebhook(notificationUrl: string, t: PaymobTransaction, secret: string) {
  const hmac = await signHmac(transactionHmacString(t), secret);
  return { url: `${notificationUrl}?hmac=${hmac}`, body: JSON.stringify({ type: 'TRANSACTION', obj: t }) };
}

/** Redirect URL with flattened, signed query params, like Paymob's transaction response callback. */
export async function signedRedirect(redirectionUrl: string, t: PaymobTransaction, secret: string) {
  const q = new URLSearchParams();
  const flat: Record<string, unknown> = {
    ...t, order: t.order.id, 'source_data.pan': t.source_data.pan,
    'source_data.type': t.source_data.type, 'source_data.sub_type': t.source_data.sub_type,
    txn_response_code: t.success ? 'APPROVED' : 'DECLINED',
  };
  delete flat.source_data;
  for (const [k, v] of Object.entries(flat)) q.set(k, String(v));
  q.set('hmac', await signHmac(redirectHmacString(q)!, secret));
  return `${redirectionUrl}?${q}`;
}

export function createMockPaymob(hmacSecret: string) {
  const intentions = new Map<string, IntentionRequest & { orderId: number }>();
  const requests: IntentionRequest[] = [];
  const app = new Hono();

  app.post('/v1/intention/', async (c) => {
    if (c.req.header('authorization') !== `Token ${MOCK_SECRET_KEY}`) return c.json({ detail: 'auth' }, 401);
    const req = await c.req.json<IntentionRequest>();
    requests.push(req);
    const clientSecret = `egy_csk_test_${crypto.randomUUID().replaceAll('-', '')}`;
    const orderId = ++seq + 217_000_000;
    intentions.set(clientSecret, { ...req, orderId });
    return c.json({ id: `pi_test_${seq}`, client_secret: clientSecret, intention_order_id: orderId, status: 'intended' }, 201);
  });

  app.get('/unifiedcheckout/', (c) => {
    const cs = c.req.query('clientSecret') ?? '';
    const it = intentions.get(cs);
    if (!it) return c.text('unknown client secret', 404);
    const amount = (it.amount / 100).toFixed(2);
    return c.html(`<!doctype html><meta charset="utf-8"><title>Mock Paymob</title>
<h1>Mock Paymob checkout</h1><p>Pay ${amount} ${it.currency}</p>
<form method="post" action="/unifiedcheckout/pay"><input type="hidden" name="cs" value="${cs}">
<button id="decline" name="result" value="decline">Decline card</button>
<button id="pay" name="result" value="success">Pay</button></form>`);
  });

  app.post('/unifiedcheckout/pay', async (c) => {
    const form = await c.req.formData();
    const it = intentions.get(String(form.get('cs')));
    if (!it) return c.text('unknown client secret', 404);
    const success = form.get('result') === 'success';
    const t = buildTransaction(it.orderId, it.amount, it.currency, it.payment_methods[0], { success });
    const hook = await signedWebhook(it.notification_url, t, hmacSecret);
    await fetch(hook.url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: hook.body });
    if (!success) return c.redirect(`/unifiedcheckout/?publicKey=x&clientSecret=${form.get('cs')}`);
    return c.redirect(await signedRedirect(it.redirection_url, t, hmacSecret));
  });

  return { app, requests };
}

if (import.meta.main) {
  const secret = Deno.env.get('PAYMOB_HMAC_SECRET');
  if (!secret) throw new Error('PAYMOB_HMAC_SECRET is not set');
  Deno.serve({ port: Number(Deno.env.get('MOCK_PORT') ?? '8791') }, createMockPaymob(secret).app.fetch);
}
