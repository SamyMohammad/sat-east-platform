# ADR-009: Web hosting on Cloudflare Pages

**Status:** Proposed · **Date:** 2026-10-07 · **Deciders:** Developer

## Context
The web build is the primary platform (ADR-006) and the only place purchases happen. It is a
static Flutter web build, so any static host works. `docs/05` §2 listed Vercel, Cloudflare Pages
and Firebase Hosting without choosing. F-3 needs a target for "deploy web to hosting on `main`".

## Decision
Host the Flutter web build on **Cloudflare Pages**. CI deploys it with `wrangler pages deploy`
on every merge to `main` (staging). A `_redirects` file (`/* /index.html 200`) serves deep links.

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Cloudflare Pages (chosen) | Free, unlimited bandwidth, commercial use allowed; same vendor as R2 (ADR-002) | One more API token in CI |
| Vercel | Connector already linked | Hobby tier bans commercial use → paid plan before launch |
| Firebase Hosting | Firebase project exists anyway for FCM (ADR-008) | 10 GB/month free transfer; widens Firebase use beyond ADR-008's "narrowly" |

## Consequences
- CI secrets: `CLOUDFLARE_API_TOKEN` (Pages edit only), `CLOUDFLARE_ACCOUNT_ID`.
- CI creates the Pages project on its first deploy (wrangler run by an AI agent turns a new Pages
  project into a Workers deploy, so it is not created from a Claude session).
- The custom domain (Q-01) is attached to the prod Pages project later.
