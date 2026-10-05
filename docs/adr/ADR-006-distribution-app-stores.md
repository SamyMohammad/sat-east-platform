# ADR-006: Distribution — web first, app stores with care

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Teacher, Developer

## Context
Students use phone, tablet and laptop. Apple App Store and Google Play generally require their own
in-app purchase systems (with commission) for digital content sold and consumed inside the app, and
reject apps that link to or describe outside purchase methods; exact rules differ by region and
change over time. Selling courses inside native apps without IAP is a common rejection reason.
Native apps, however, give stronger content protection (screenshot blocking) and push notifications.

## Decision
1. **Launch on the web** (responsive Flutter web, works on all devices) — all purchases happen here.
2. Ship **Android and iOS apps as access apps** for students who already have an account: login,
   learning, mocks — **no prices, buy buttons or links to purchase** inside the apps.
3. Before store submission, re-check current Apple/Google guidelines for the target storefronts;
   if access-only apps are rejected, choose between adding IAP (price includes commission) or
   staying web-only (installable PWA).

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Web-first + access-only apps (proposed) | No commission; fastest launch | Store review risk for iOS |
| Native apps with IAP | Store-compliant purchase | 15–30% commission, IAP integration work, refund handling via stores |
| Web/PWA only | Simplest | No FLAG_SECURE / weaker protection; no store presence |

## Consequences
- Checkout code exists only in the web build (compile-time flag `ENABLE_PURCHASE`).
- App Store review needs a **demo student account** with an active enrollment.
- Revisit after the first store review outcome.
