// Spike of the future `api` /checkout route and the `payment-webhook` function (ADR-003).
//
//   POST /checkout             { courseId, currency, coupon? } → { orderId, checkoutUrl }
//   POST /payment-webhook?hmac  Paymob processed callback — the ONLY path that enrols (PAY-03)
//   GET  /payment-return?…      Paymob redirect — UX only, never enrols
//   GET  /orders/:id            status poll for the return page (realtime in the real app)
//   GET  /                      test page
//
// SPIKE: the caller names itself in `x-spike-user`. The real route uses verifyAuth (EF template).
import { type Context, Hono } from 'npm:hono@4.13.13';
import { type PaymobTransaction, redirectHmacString, transactionHmacString, verifyHmac } from './hmac.ts';
import type { PaymobClient } from './paymob.ts';
import type { OrderStatus, Store } from './store.ts';

export type Deps = {
  store: Store;
  paymob: PaymobClient;
  hmacSecret: string;
  /** Integration ids we created checkouts with; a callback from any other integration is refused. */
  integrationIds: number[];
  /** Public base URL Paymob can reach (tunnel in dev), for notification + redirection URLs. */
  publicBaseUrl: string;
  page: string;
  now: () => number; // epoch ms; injected for tests
  log: (event: string, fields?: Record<string, string | number | boolean>) => void;
};

type ErrorCode = 'not_authenticated' | 'forbidden' | 'invalid_input' | 'payment_invalid' | 'internal';

function fail(c: Context, code: ErrorCode, status: 400 | 401 | 403 | 404 | 502) {
  return c.json({ error: { code, message: code } }, status);
}

function isTransaction(o: unknown): o is PaymobTransaction {
  const t = o as PaymobTransaction;
  const bools = ['pending', 'success', 'is_auth', 'is_capture', 'is_standalone_payment', 'is_voided',
    'is_refunded', 'is_3d_secure', 'has_parent_transaction', 'error_occured'] as const;
  return !!t && typeof t.id === 'number' && typeof t.amount_cents === 'number' &&
    typeof t.integration_id === 'number' && typeof t.owner === 'number' &&
    typeof t.created_at === 'string' && typeof t.currency === 'string' &&
    bools.every((b) => typeof t[b] === 'boolean') &&
    typeof t.order?.id === 'number' && typeof t.source_data?.pan === 'string' &&
    typeof t.source_data?.type === 'string' && typeof t.source_data?.sub_type === 'string';
}

export function createApp(deps: Deps) {
  const { store } = deps;
  const app = new Hono();

  app.get('/', (c) => c.html(deps.page));

  app.post('/checkout', async (c) => {
    const user = c.req.header('x-spike-user')?.trim();
    if (!user) return fail(c, 'not_authenticated', 401);
    // Only ids from the client; any amount it sends is ignored (rule 2).
    const body = await c.req.json<{ courseId?: string; currency?: string; coupon?: string }>().catch(() => null);
    if (!body?.courseId || !body.currency) return fail(c, 'invalid_input', 400);
    const q = store.quote(body.courseId, body.currency, body.coupon?.trim() || null, deps.now());
    if ('error' in q) return fail(c, 'invalid_input', 400);

    const orderId = crypto.randomUUID();
    const order = {
      id: orderId, userId: user, courseId: body.courseId, priceId: q.price.id,
      couponCode: q.coupon?.code ?? null, amountMinor: q.amountMinor, currency: q.price.currency,
      status: 'pending' as OrderStatus, gatewayOrderId: null as string | null, gatewayTxnId: null,
      createdAt: deps.now(), paidAt: null,
    };
    store.orders.set(orderId, order);
    try {
      const intention = await deps.paymob.createIntention({
        amount: q.amountMinor,
        currency: q.price.currency,
        payment_methods: deps.integrationIds,
        items: [{ name: body.courseId, amount: q.amountMinor, description: 'Course access', quantity: 1 }],
        // Real version: from profiles (AUTH-02). Paymob requires these fields.
        billing_data: { first_name: user, last_name: 'Student', phone_number: '+201000000000', email: 'student@example.com' },
        special_reference: orderId,
        notification_url: `${deps.publicBaseUrl}/payment-webhook`,
        redirection_url: `${deps.publicBaseUrl}/payment-return`,
      });
      order.gatewayOrderId = String(intention.intention_order_id);
      deps.log('checkout.created', { orderId, gatewayOrderId: order.gatewayOrderId, amount: q.amountMinor });
      return c.json({ orderId, checkoutUrl: deps.paymob.checkoutUrl(intention.client_secret) });
    } catch (e) {
      order.status = 'failed';
      deps.log('checkout.gateway_error', { orderId, error: e instanceof Error ? e.message : 'unknown' });
      return fail(c, 'payment_invalid', 502);
    }
  });

  app.post('/payment-webhook', async (c) => {
    const body = await c.req.json<{ type?: string; obj?: unknown }>().catch(() => null);
    if (!body?.type) return fail(c, 'invalid_input', 400);
    // Only TRANSACTION events matter here (TOKEN = saved cards, unused).
    if (body.type !== 'TRANSACTION') return c.json({ ok: true, result: 'ignored' });
    if (!isTransaction(body.obj)) {
      deps.log('webhook.malformed');
      return fail(c, 'invalid_input', 400);
    }
    const t = body.obj;
    if (!(await verifyHmac(transactionHmacString(t), c.req.query('hmac'), deps.hmacSecret))) {
      // PAY-03: a forged or unsigned callback creates nothing and is logged (no payload, no PII).
      deps.log('webhook.bad_hmac', { txnId: t.id });
      return fail(c, 'forbidden', 401);
    }
    // Signed from here on. Look up by the SIGNED Paymob order id, never merchant_order_id.
    const order = store.findByGatewayOrderId(String(t.order.id));
    if (!order) {
      deps.log('webhook.unknown_order', { txnId: t.id, gatewayOrderId: t.order.id });
      return c.json({ ok: true, result: 'unknown_order' });
    }
    if (!deps.integrationIds.includes(t.integration_id)) {
      deps.log('webhook.unknown_integration', { txnId: t.id, orderId: order.id });
      return c.json({ ok: true, result: 'unknown_integration' });
    }
    if (t.amount_cents !== order.amountMinor || t.currency !== order.currency) {
      deps.log('webhook.amount_mismatch', { txnId: t.id, orderId: order.id });
      return c.json({ ok: true, result: 'amount_mismatch' });
    }
    if (t.pending) return c.json({ ok: true, result: 'pending' });
    const paid = t.success && !t.is_voided && !t.is_refunded && !t.error_occured;
    const result = store.applyTransaction(order, String(t.id), paid, deps.now());
    deps.log(`webhook.${result}`, { txnId: t.id, orderId: order.id });
    return c.json({ ok: true, result });
  });

  app.get('/payment-return', async (c) => {
    const q = new URL(c.req.url).searchParams;
    const data = redirectHmacString(q);
    if (data === null || !(await verifyHmac(data, q.get('hmac'), deps.hmacSecret))) {
      deps.log('return.bad_hmac');
      return c.redirect('/?error=bad_signature');
    }
    const order = store.findByGatewayOrderId(q.get('order')!);
    if (!order) return c.redirect('/?error=unknown_order');
    // UX hint only. Enrolment waits for the webhook; the page polls /orders/:id.
    return c.redirect(`/?order=${order.id}&gateway=${q.get('success') === 'true' ? 'success' : 'failed'}`);
  });

  app.get('/orders/:id', (c) => {
    const user = c.req.header('x-spike-user')?.trim();
    const order = store.orders.get(c.req.param('id'));
    // Same answer for "not yours" and "does not exist".
    if (!user || !order || order.userId !== user) return fail(c, 'forbidden', 404);
    const enrollment = store.enrollments.get(`${order.userId}|${order.courseId}`);
    return c.json({
      status: order.status,
      amountMinor: order.amountMinor,
      currency: order.currency,
      enrolled: enrollment?.orderId === order.id,
      expiresAt: enrollment ? new Date(enrollment.expiresAt).toISOString() : null,
    });
  });

  return app;
}
