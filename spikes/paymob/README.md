# Spike: Paymob checkout + HMAC webhook (ADR-003, docs/15 §1 row 8)

Throwaway code. Findings: [`docs/spikes/2026-10-08-paymob.md`](../../docs/spikes/2026-10-08-paymob.md).
Not analysed by CI and not deployed. The PAY stories rebuild it as the `api` `/checkout` route,
the `payment-webhook` function and Postgres RPCs.

| Path | What |
|---|---|
| `server/app.ts` | `/checkout`, `/payment-webhook`, `/payment-return`, `/orders/:id`, test page |
| `server/hmac.ts` | Paymob HMAC-SHA512 strings + constant-time verify |
| `server/store.ts` | In-memory prices / coupons / orders / enrollments (docs/06 shape) |
| `server/mock_paymob.ts` | Fake Paymob: intention API + checkout page that signs callbacks |
| `server/app_test.ts` | 16 Deno tests |
| `web/index.html` | Plain test page: buy → Paymob → return → poll until enrolled |
| `e2e/web_e2e.mjs` | Playwright run: `mock` (automatic) or `live` (you pay by hand) |

Needs: Deno 2. For the e2e: Node 22 + Playwright + Chrome.

## A. Without Paymob (mock, 2 minutes)
```sh
deno test -A spikes/paymob/server/
# PowerShell: $env:NAME = "value" instead of export
export PAYMOB_HMAC_SECRET=local_test_secret_0123456789
deno run -A spikes/paymob/server/mock_paymob.ts &                                # :8791
PAYMOB_SECRET_KEY=mock_secret_key PAYMOB_PUBLIC_KEY=pk_test PAYMOB_INTEGRATION_IDS=4551234 \
PUBLIC_BASE_URL=http://localhost:8790 PAYMOB_BASE_URL=http://localhost:8791 \
deno run -A spikes/paymob/server/main.ts                                         # :8790
```
Open http://localhost:8790 → Continue to payment → Decline once → Pay → "Enrolled ✔".

## B. Live Paymob test mode
### 1. Create the test account (once)
1. Sign up at **accept.paymob.com** (Egypt). Test mode works before the business papers (Q-03).
2. Dashboard → switch to **Test mode**.
3. **Settings → Account info:** copy **Secret key**, **Public key** and **HMAC secret**.
4. **Developers → Payment integrations:** note the **integration id** of the test *Online Card*
   integration (and *Mobile Wallet*, if listed).
5. Keep these in your shell or a local `.env` (git-ignored). Never put them in chat, in
   `apps/client/env/*.json` or in a commit.

### 2. Run
```sh
# Tunnel so Paymob can reach your PC (no Cloudflare account needed):
cloudflared tunnel --url http://localhost:8790        # prints https://<random>.trycloudflare.com
export PAYMOB_SECRET_KEY=... PAYMOB_PUBLIC_KEY=... PAYMOB_HMAC_SECRET=...
export PAYMOB_INTEGRATION_IDS=<card id>[,<wallet id>]
export PUBLIC_BASE_URL=https://<random>.trycloudflare.com
deno run -A spikes/paymob/server/main.ts
```
Open `PUBLIC_BASE_URL` in the browser, not localhost, so the return page is on the same origin.
Pay with Paymob's **test card** (shown in their docs and dashboard under test mode).

### 3. Checklist → fill in "Live results" in the findings doc
1. Checkout opens Paymob's page with the right amount (1,500.00 EGP, or 1,350.00 with `SPIKE10`).
2. Test card success → server log `webhook.paid`, page shows "Enrolled".
3. Check whether the intention response has `intention_order_id`. The log line `checkout.created`
   shows `gatewayOrderId`. If it is missing, the server returns 502 with
   `paymob intention: unexpected response shape`.
4. Declined test card, then a retry on the same page → log `webhook.declined`, then `webhook.paid`.
5. Webhook HMAC verifies, i.e. no `webhook.bad_hmac` for genuine Paymob calls. This confirms the
   field order against the real gateway.
6. The redirect back has a valid HMAC: the page says "Payment received…", not "rejected".
7. Re-send a webhook from the dashboard (Transactions → the payment → resend callback, if
   offered) → log `webhook.duplicate`, still one enrolment.
8. USD price: does test mode accept `currency: USD` on your integration? Note the error if not.
9. Mobile wallet test (if the integration exists): same as 2.
