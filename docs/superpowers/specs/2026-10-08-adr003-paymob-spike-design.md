# Phase 0 row 8 — Spike: Paymob checkout + HMAC webhook (design)

Story: docs/15 §1 row 8 (ADR-003 action item 2). Sources: ADR-003, `docs/02` PAY-02/03/05/07,
`docs/05` §5.1, `docs/06` (`prices`, `coupons`, `orders`, `enrollments`), `docs/07` §7, NFR-10.

## Goal
In about a day, prove the money path before the PAY stories. The server creates a Paymob checkout,
and the student pays on Paymob's hosted page. Only Paymob's signed webhook marks the order paid and
creates the enrolment (PAY-03, CLAUDE.md rule 2). Write down what the real build must do.

## Scope
**In:** `spikes/paymob/` — a Deno + Hono server shaped like the future `api` `/checkout` route
and the `payment-webhook` function, with an in-memory store in the shape of `docs/06`, a mock
Paymob for tests, a plain HTML test page, and a runbook for a live Paymob **test-mode** run.

**Out:** migrations, RPCs, real Edge Functions, Flutter purchase UI (ADR-006), receipts (PAY-10),
renewals (PAY-08), refunds (PAY-11), reconciliation cron. All of these belong to the PAY stories.
The decisions below carry over to them.

Paymob's hosts are blocked from the development sandbox, so the live run happens on the
developer's machine (runbook). Paymob's API shape was cross-checked against the source of
`@m-nasser-m/paymob-sdk-eg`, because the official docs are unreachable from the sandbox.

## Paymob facts used
- `POST https://accept.paymob.com/v1/intention/`, `Authorization: Token <secret key>`. Body:
  `amount` (minor units), `currency`, `payment_methods` (integration ids), `items`, `billing_data`
  (first_name, last_name, phone_number, email), `special_reference`, `notification_url`,
  `redirection_url`. The response holds `id`, `client_secret` and `intention_order_id`.
- Checkout page: `https://accept.paymob.com/unifiedcheckout/?publicKey=<pk>&clientSecret=<cs>`.
- Processed callback: `POST {type: "TRANSACTION", obj}` with `?hmac=`. HMAC-SHA512 (hex) uses the
  dashboard HMAC secret over these fields joined with no separator: amount_cents, created_at,
  currency, error_occured, has_parent_transaction, id, integration_id, is_3d_secure, is_auth,
  is_capture, is_refunded, is_standalone_payment, is_voided, order.id, owner, pending,
  source_data.pan, source_data.sub_type, source_data.type, success. Booleans are written as
  `true` / `false`.
- Redirect callback: `GET` with the same fields flattened (`order`, `source_data.pan`, …) + `hmac`.

## Decisions
1. **Find the order by the signed Paymob order id** (`obj.order.id`, stored as `gateway_order_id`
   at checkout). Never use `merchant_order_id` or `special_reference`: the HMAC does not cover them,
   so a genuine callback could be replayed and pointed at a different pending order.
2. After the HMAC check, all of these must hold: `success && !pending && !is_voided && !is_refunded
   && !error_occured`, `integration_id` is in our allow-list, and `amount_cents` + `currency` equal
   the stored order. Otherwise log it and create no enrolment. A signed failure marks the order `failed`.
3. **Idempotent** on `obj.id` (`gateway_txn_id` unique). A repeated delivery returns 200 and changes nothing.
4. Bad or missing HMAC → 401, and the log line carries no payload and no PII. A well-formed signed event → 200,
   so Paymob does not retry.
5. **The redirect is UX only.** Its HMAC is checked so the page can say "payment received, activating…",
   but it never enrols. The page then polls the order until the webhook has run (realtime in the real app).
6. **The server sets the amount** from `prices` (+ coupon). The client sends only `courseId` and an
   optional coupon code.
7. Secret key and HMAC secret stay in server env. The public key is the only Paymob value the browser sees.
8. Access window (PAY-07): `expires_at = max(target_test_date + grace_days, now + min_days)`.
   Spike config is 14 / 60; the PAY story moves both to `settings`.

## Success criteria
- Deno tests cover HMAC (order, formatting, tampering), checkout pricing, webhook paths (valid,
  duplicate, forged, mismatch, failure, re-pointed order, unknown integration) and the redirect.
- Our HMAC agrees with the reference SDK on the same payload.
- Web flow against the mock: checkout → pay → webhook → page shows "enrolled".
- Live test-mode run: runbook steps the developer runs; the results go into the findings doc.
