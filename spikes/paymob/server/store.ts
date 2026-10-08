// In-memory stand-in for prices / coupons / orders / enrollments (docs/06). The PAY story moves
// this into Postgres: markPaid becomes one RPC, called by payment-webhook with service_role.

export type Price = { id: string; courseId: string; currency: string; amountMinor: number; active: boolean };
export type Coupon = {
  code: string; courseId: string | null; percentOff: number | null; amountOffMinor: number | null;
  maxUses: number | null; usedCount: number; expiresAt: number | null; active: boolean;
};
export type OrderStatus = 'pending' | 'paid' | 'failed';
export type Order = {
  id: string; userId: string; courseId: string; priceId: string; couponCode: string | null;
  amountMinor: number; currency: string; status: OrderStatus;
  gatewayOrderId: string | null; gatewayTxnId: string | null; createdAt: number; paidAt: number | null;
};
export type Enrollment = {
  userId: string; courseId: string; orderId: string; status: 'active';
  startsAt: number; expiresAt: number; targetTestDate: number | null;
};

const DAY = 86_400_000;

export class Store {
  prices: Price[] = [];
  coupons: Coupon[] = [];
  orders = new Map<string, Order>();
  enrollments = new Map<string, Enrollment>(); // key: userId|courseId (unique in docs/06)
  /** Stand-in for profiles.target test date per course. */
  targetTestDate = new Map<string, number>();

  constructor(private readonly cfg: { graceDays: number; minDays: number }) {}

  /** Server-side price (PAY-04/05): never from the client. Null = unknown course or bad coupon. */
  quote(courseId: string, currency: string, couponCode: string | null, now: number):
    { price: Price; amountMinor: number; coupon: Coupon | null } | { error: 'unknown_course' | 'invalid_coupon' } {
    const price = this.prices.find((p) => p.courseId === courseId && p.currency === currency && p.active);
    if (!price) return { error: 'unknown_course' };
    if (!couponCode) return { price, amountMinor: price.amountMinor, coupon: null };
    const c = this.coupons.find((x) => x.code === couponCode);
    const usable = c && c.active && (c.courseId === null || c.courseId === courseId) &&
      (c.expiresAt === null || c.expiresAt > now) && (c.maxUses === null || c.usedCount < c.maxUses);
    if (!usable) return { error: 'invalid_coupon' };
    const off = c.percentOff !== null ? Math.floor(price.amountMinor * c.percentOff / 100) : c.amountOffMinor!;
    return { price, amountMinor: Math.max(0, price.amountMinor - off), coupon: c };
  }

  findByGatewayOrderId(gatewayOrderId: string): Order | undefined {
    for (const o of this.orders.values()) if (o.gatewayOrderId === gatewayOrderId) return o;
    return undefined;
  }

  hasTxn(txnId: string): boolean {
    for (const o of this.orders.values()) if (o.gatewayTxnId === txnId) return true;
    return false;
  }

  /**
   * Webhook outcome for one verified transaction. Idempotent on txnId (gateway_txn_id unique):
   * the real version is `update orders … where status = 'pending'` + `insert enrollments … on
   * conflict (user_id, course_id) do update` in one transaction.
   *
   * A declined attempt leaves the order PENDING: Paymob's checkout lets the student retry on the
   * same order, and a later success must still enrol. Pending orders that never succeed are
   * closed by the reconciliation cron (docs/07 §7).
   */
  applyTransaction(order: Order, txnId: string, success: boolean, now: number):
    'duplicate' | 'declined' | 'already_paid' | 'paid' {
    if (this.hasTxn(txnId)) return 'duplicate';
    if (!success) return 'declined';
    // A second successful charge on a paid order = double payment → teacher refunds (PAY-11).
    if (order.status !== 'pending') return 'already_paid';
    order.gatewayTxnId = txnId;
    order.status = 'paid';
    order.paidAt = now;
    if (order.couponCode) {
      const c = this.coupons.find((x) => x.code === order.couponCode);
      if (c) c.usedCount++;
    }
    const key = `${order.userId}|${order.courseId}`;
    const target = this.targetTestDate.get(order.userId) ?? null;
    // PAY-07: expires_at = max(target_test_date + grace_days, now + min_days)
    const expiresAt = Math.max(
      target === null ? 0 : target + this.cfg.graceDays * DAY,
      now + this.cfg.minDays * DAY,
    );
    this.enrollments.set(key, {
      userId: order.userId, courseId: order.courseId, orderId: order.id, status: 'active',
      startsAt: now, expiresAt, targetTestDate: target,
    });
    return 'paid';
  }
}
