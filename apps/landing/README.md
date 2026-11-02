# Landing page

Static marketing page for Abdelrahman Elmenshawy | SAT & EST Math. Plain HTML, CSS and JS with no build step and self-hosted fonts. Copy comes from the teacher's brief (2026-10-27). The brand rules are in `docs/superpowers/specs/2026-10-29-brand-rollout-design.md`.

## Run locally

Open `index.html` in a browser, or run `npx serve apps/landing`.

## Deploy (Cloudflare)

Static assets on Cloudflare Workers (the successor to Pages), project `menshawy-landing`, live at
https://menshawy-landing.tech11.workers.dev. It is separate from the Flutter app. Deploy by hand from this folder:

```
npx wrangler@4 deploy
```

`wrangler.jsonc` holds the config; `.assetsignore` keeps this README and the config off the site.

## Before launch

- The app links point at `https://sat-prod.pages.dev`. When the domain is decided (Q-01), update `APP_ORIGIN` in `main.js` and the `href`s in `index.html`.
- When a custom domain is added, point `og:image` in `index.html` at it (it uses the workers.dev URL today).
- Mark Cognia as awarded only after the credential arrives.
