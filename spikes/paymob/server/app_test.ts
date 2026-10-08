// deno test -A spikes/paymob/server/
import { assert, assertEquals, assertMatch } from 'jsr:@std/assert@1.0.19';
import { createApp } from './app.ts';
import { type PaymobTransaction, redirectHmacString, signHmac, transactionHmacString, verifyHmac } from './hmac.ts';
import { buildTransaction, createMockPaymob, MOCK_SECRET_KEY, signedRedirect, signedWebhook } from './mock_paymob.ts';
import { HttpPaymobClient } from './paymob.ts';
import { Store } from './store.ts';

const HMAC = 'test_hmac_secret_0123456789abcdef';
const INTEGRATION = 4551234;
const NOW = Date.parse('2026-10-08T12:00:00Z');
const DAY = 86_400_000;
const BASE = 'http://spike.test';

function setup() {
  const mock = createMockPaymob(HMAC);
  const store = new Store({ graceDays: 14, minDays: 60 });
  store.prices.push(
    { id: 'p-egp', courseId: 'sat-math', currency: 'EGP', amountMinor: 150_000, active: true },
    { id: 'p-old', courseId: 'est-math', currency: 'EGP', amountMinor: 90_000, active: false },
  );
  store.coupons.push(
    { code: 'TEN', courseId: 'sat-math', percentOff: 10, amountOffMinor: null, maxUses: 1, usedCount: 0, expiresAt: null, active: true },
    { code: 'OLD', courseId: null, percentOff: null, amountOffMinor: 5_000, maxUses: null, usedCount: 0, expiresAt: NOW - 1, active: true },
  );
  const logs: string[] = [];
  // The real HTTP client, with fetch routed to the mock Paymob.
  const paymob = new HttpPaymobClient({ baseUrl: 'http://mock.paymob', secretKey: MOCK_SECRET_KEY, publicKey: 'pk_test' });
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => await mock.app.request(String(input), init);
  const app = createApp({
    store, paymob, hmacSecret: HMAC, integrationIds: [INTEGRATION], publicBaseUrl: BASE,
    page: '<p>page</p>', now: () => NOW, log: (e) => logs.push(e),
  });
  const restore = () => { globalThis.fetch = realFetch; };
  return { app, store, mock, logs, restore };
}

async function checkout(app: ReturnType<typeof createApp>, body: Record<string, unknown>, user = 'sara') {
  return await app.request(`${BASE}/checkout`, {
    method: 'POST', headers: { 'content-type': 'application/json', 'x-spike-user': user }, body: JSON.stringify(body),
  });
}

async function newOrder(s: ReturnType<typeof setup>, user = 'sara', coupon?: string) {
  const res = await checkout(s.app, { courseId: 'sat-math', currency: 'EGP', coupon }, user);
  assertEquals(res.status, 200);
  const { orderId } = await res.json();
  return s.store.orders.get(orderId)!;
}

async function deliver(app: ReturnType<typeof createApp>, t: PaymobTransaction, secret = HMAC) {
  const hook = await signedWebhook(`${BASE}/payment-webhook`, t, secret);
  const res = await app.request(hook.url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: hook.body });
  return { status: res.status, body: await res.json() };
}

function txFor(order: { gatewayOrderId: string | null; amountMinor: number; currency: string }, o: Partial<PaymobTransaction> = {}) {
  return buildTransaction(Number(order.gatewayOrderId), order.amountMinor, order.currency, INTEGRATION, o);
}

Deno.test('PAY-03 hmac: field order and formatting; tamper and wrong secret fail', async () => {
  const t = buildTransaction(217503754, 150000, 'EGP', INTEGRATION);
  const s = transactionHmacString(t);
  assert(s.startsWith('1500002026-10-08T15:01:02.123456EGPfalsefalse'));
  assert(s.endsWith('2346MasterCardcardtrue'));
  const sig = await signHmac(s, HMAC);
  assert(await verifyHmac(s, sig, HMAC));
  assert(!(await verifyHmac(transactionHmacString({ ...t, amount_cents: 100 }), sig, HMAC)));
  assert(!(await verifyHmac(transactionHmacString({ ...t, success: false }), sig, HMAC)));
  assert(!(await verifyHmac(transactionHmacString({ ...t, order: { id: 1 } }), sig, HMAC)));
  assert(!(await verifyHmac(s, sig, 'another_secret')));
  assert(!(await verifyHmac(s, 'abc', HMAC)));
  assert(!(await verifyHmac(s, null, HMAC)));
});

Deno.test('PAY-03 hmac: merchant_order_id is not part of the signed string', () => {
  const t = buildTransaction(1, 100, 'EGP', INTEGRATION);
  assertEquals(
    transactionHmacString({ ...t, order: { id: 1, merchant_order_id: 'a' } }),
    transactionHmacString({ ...t, order: { id: 1, merchant_order_id: 'b' } }),
  );
});

Deno.test('PAY-02 checkout: server-side price, client amount ignored, intention carries callback URLs', async () => {
  const s = setup();
  try {
    const res = await checkout(s.app, { courseId: 'sat-math', currency: 'EGP', amount: 1 });
    assertEquals(res.status, 200);
    const { orderId, checkoutUrl } = await res.json();
    assertMatch(checkoutUrl, /^http:\/\/mock\.paymob\/unifiedcheckout\/\?publicKey=pk_test&clientSecret=egy_csk_test_/);
    const order = s.store.orders.get(orderId)!;
    assertEquals([order.amountMinor, order.currency, order.status], [150_000, 'EGP', 'pending']);
    assert(order.gatewayOrderId);
    const req = s.mock.requests[0];
    assertEquals(req.amount, 150_000);
    assertEquals(req.payment_methods, [INTEGRATION]);
    assertEquals(req.special_reference, orderId);
    assertEquals(req.notification_url, `${BASE}/payment-webhook`);
    assertEquals(req.redirection_url, `${BASE}/payment-return`);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-05 checkout: coupon applied; expired, inactive price, unknown course refused; auth required', async () => {
  const s = setup();
  try {
    assertEquals((await newOrder(s, 'sara', 'TEN')).amountMinor, 135_000);
    assertEquals((await checkout(s.app, { courseId: 'sat-math', currency: 'EGP', coupon: 'OLD' })).status, 400);
    assertEquals((await checkout(s.app, { courseId: 'est-math', currency: 'EGP' })).status, 400);
    assertEquals((await checkout(s.app, { courseId: 'nope', currency: 'EGP' })).status, 400);
    assertEquals((await checkout(s.app, { courseId: 'sat-math', currency: 'EGP' }, '')).status, 401);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: valid payment → paid + one enrolment with PAY-07 window', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    s.store.targetTestDate.set('sara', NOW + 120 * DAY);
    const r = await deliver(s.app, txFor(order));
    assertEquals([r.status, r.body.result], [200, 'paid']);
    assertEquals(order.status, 'paid');
    const e = s.store.enrollments.get('sara|sat-math')!;
    assertEquals(e.orderId, order.id);
    assertEquals(e.expiresAt, NOW + 134 * DAY); // target + 14 grace > now + 60
  } finally {
    s.restore();
  }
});

Deno.test('PAY-07 webhook: no target date → minimum 60 days', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    await deliver(s.app, txFor(order));
    assertEquals(s.store.enrollments.get('sara|sat-math')!.expiresAt, NOW + 60 * DAY);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: duplicate delivery is idempotent', async () => {
  const s = setup();
  try {
    const order = await newOrder(s, 'sara', 'TEN');
    const t = txFor(order);
    assertEquals((await deliver(s.app, t)).body.result, 'paid');
    assertEquals((await deliver(s.app, t)).body.result, 'duplicate');
    assertEquals(s.store.enrollments.size, 1);
    assertEquals(s.store.coupons[0].usedCount, 1);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: forged or unsigned → 401, nothing created, logged', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    const r = await deliver(s.app, txFor(order), 'attacker_secret');
    assertEquals(r.status, 401);
    const body = JSON.stringify({ type: 'TRANSACTION', obj: txFor(order) });
    const unsigned = await s.app.request(`${BASE}/payment-webhook`, { method: 'POST', body, headers: { 'content-type': 'application/json' } });
    assertEquals(unsigned.status, 401);
    assertEquals(order.status, 'pending');
    assertEquals(s.store.enrollments.size, 0);
    assertEquals(s.logs.filter((l) => l === 'webhook.bad_hmac').length, 2);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: signed but amount or currency differs from the order → no enrolment', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    assertEquals((await deliver(s.app, txFor(order, { amount_cents: 100 }))).body.result, 'amount_mismatch');
    assertEquals((await deliver(s.app, txFor(order, { currency: 'USD' }))).body.result, 'amount_mismatch');
    assertEquals(s.store.enrollments.size, 0);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: declined attempt keeps the order pending, a later retry still enrols', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    assertEquals((await deliver(s.app, txFor(order, { success: false }))).body.result, 'declined');
    assertEquals(order.status, 'pending');
    assertEquals((await deliver(s.app, txFor(order))).body.result, 'paid');
    assertEquals(s.store.enrollments.size, 1);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: second successful charge on a paid order is flagged, not re-applied', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    await deliver(s.app, txFor(order));
    assertEquals((await deliver(s.app, txFor(order))).body.result, 'already_paid');
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: pending, voided, refunded or errored → no enrolment', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    assertEquals((await deliver(s.app, txFor(order, { pending: true }))).body.result, 'pending');
    for (const o of [{ is_voided: true }, { is_refunded: true }, { error_occured: true }]) {
      assertEquals((await deliver(s.app, txFor(order, o))).body.result, 'declined');
    }
    assertEquals(s.store.enrollments.size, 0);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: genuine callback re-pointed via merchant_order_id cannot pay another order', async () => {
  const s = setup();
  try {
    const cheap = await newOrder(s, 'mallory');
    const victimOrder = await newOrder(s, 'sara');
    // Mallory's own (signed) payment, with the unsigned merchant_order_id swapped to Sara's order.
    const t = txFor(cheap, { order: { id: Number(cheap.gatewayOrderId), merchant_order_id: victimOrder.id } });
    assertEquals((await deliver(s.app, t)).body.result, 'paid');
    assertEquals(cheap.status, 'paid');
    assertEquals(victimOrder.status, 'pending');
    assert(!s.store.enrollments.has('sara|sat-math'));
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 webhook: unknown integration, unknown order, non-transaction, malformed', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    assertEquals((await deliver(s.app, txFor(order, { integration_id: 999 }))).body.result, 'unknown_integration');
    assertEquals((await deliver(s.app, buildTransaction(42, 150_000, 'EGP', INTEGRATION))).body.result, 'unknown_order');
    const token = await s.app.request(`${BASE}/payment-webhook`, { method: 'POST', body: JSON.stringify({ type: 'TOKEN', obj: {} }) });
    assertEquals((await token.json()).result, 'ignored');
    const bad = await s.app.request(`${BASE}/payment-webhook?hmac=x`, { method: 'POST', body: JSON.stringify({ type: 'TRANSACTION', obj: { id: 'x' } }) });
    assertEquals(bad.status, 400);
    assertEquals(s.store.enrollments.size, 0);
  } finally {
    s.restore();
  }
});

Deno.test('PAY-03 redirect: signed return is UX only; bad signature rejected', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    const url = await signedRedirect(`${BASE}/payment-return`, txFor(order), HMAC);
    const ok = await s.app.request(url);
    assertEquals(ok.status, 302);
    assertEquals(ok.headers.get('location'), `/?order=${order.id}&gateway=success`);
    assertEquals(order.status, 'pending', 'redirect never enrols');
    assertEquals(s.store.enrollments.size, 0);
    const forged = await s.app.request(await signedRedirect(`${BASE}/payment-return`, txFor(order), 'attacker'));
    assertEquals(forged.headers.get('location'), '/?error=bad_signature');
    assert(redirectHmacString(new URLSearchParams('a=1')) === null);
  } finally {
    s.restore();
  }
});

Deno.test('orders: status visible to the owner only', async () => {
  const s = setup();
  try {
    const order = await newOrder(s);
    await deliver(s.app, txFor(order));
    const own = await s.app.request(`${BASE}/orders/${order.id}`, { headers: { 'x-spike-user': 'sara' } });
    const body = await own.json();
    assertEquals([body.status, body.enrolled], ['paid', true]);
    const other = await s.app.request(`${BASE}/orders/${order.id}`, { headers: { 'x-spike-user': 'mallory' } });
    assertEquals(other.status, 404);
  } finally {
    s.restore();
  }
});
