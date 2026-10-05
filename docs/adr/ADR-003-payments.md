# ADR-003: Payments

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Teacher (legal/business), Developer

## Context
One-time course purchases from Egypt and abroad. Egyptian buyers use cards, mobile wallets,
InstaPay, cash. International buyers use Visa/Mastercard. Teacher's business registration status
is unknown (blocking — Q-03).

## Decision
**Paymob** as the online gateway (cards incl. international, mobile wallets; kiosk/cash options
where available) **plus** in-house **activation codes** for cash/InstaPay/offline payments.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Paymob (proposed) | Strong in Egypt, cards + wallets, good API/webhooks | Requires KYC/commercial papers; EGP settlement |
| Fawry | Kiosk cash network, widely trusted | Weaker for international cards; separate integration |
| Stripe | Best DX, global | Not available for Egyptian-registered businesses (verify) |
| Activation codes only | Zero gateway fees, no papers | Manual, doesn't scale, no automation |

## Consequences
- Activation codes ship in Phase 1 regardless → teacher can sell even before gateway KYC completes.
- Display USD prices to international users; settlement remains EGP — confirm FX handling with Paymob.
- Webhook security: HMAC verification, idempotency on transaction id, server-side price calculation.
- Legal pages (Terms, Privacy, Refund policy) are a gateway onboarding requirement.

## Action items
1. [ ] Teacher: confirm commercial register / tax card; start Paymob onboarding (can take weeks).
2. [ ] Developer: integrate in test mode early; codes as fallback.
