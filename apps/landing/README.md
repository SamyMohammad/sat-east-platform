# Landing page

Static marketing page for Abdelrahman Elmenshawy | SAT & EST Math. Plain HTML, CSS and JS with no build step and self-hosted fonts. Copy comes from the teacher's brief (2026-10-27). The brand rules are in `docs/superpowers/specs/2026-10-29-brand-rollout-design.md`.

## Run locally

Open `index.html` in a browser, or run `npx serve apps/landing`.

## Deploy (Cloudflare Pages)

Create a separate Pages project. It is not the Flutter app's project.

- Build command: none
- Output directory: `apps/landing`

## Before launch

- The app links point at `https://sat-prod.pages.dev`. When the domain is decided (Q-01), update `APP_ORIGIN` in `main.js` and the `href`s in `index.html`.
- Make `og:image` in `index.html` absolute (`https://<landing-domain>/assets/og.png`).
- Replace `assets/portrait.webp` with a cutout of the original high-resolution photo. The current one is 532×690.
- Mark Cognia as awarded only after the credential arrives.
