# Brand rollout: logo, palette, landing page

Date: 2026-10-29 · Status: approved by user in chat (2026-10-29)

## Why

The teacher supplied a landing-page brief, an archived logo and a portrait (`D:\books\New folder`). Until now the product had no identity (PRODUCT.md: "No logo, colours, photos"). This rollout gives the product one identity across the public landing page and the app, so the closed beta launches looking like the teacher's platform and not a template.

## Decisions (user, 2026-10-29)

- Name spelling: **Abdelrahman Elmenshawy**. The brief and old logo say "Abdelrhman"; that spelling is not used anywhere.
- Landing page: a **static page** in `apps/landing/` (HTML/CSS/JS, no build), deployed separately from the Flutter web app. CTAs link into the app (`/sign-up`, `/sign-in`).
- Palette: the brief's Navy `#102A43`, Baby Blue `#B8E0F6`, White and `#F4F9FC` apply to the **whole app now**, light and dark. Goldens are re-baselined in the same change.
- Logo: a vector redraw of the "A∫E" monogram. The integral sign sits between A and E. Tagline "SAT & EST MATH". "Certified Math Instructor" and "IGCSE Mathematics" are dropped (unverified / obsolete).

## Truth rules for all brand copy

- No testimonials, scores, student counts or prices.
- College Board: "SAT Professional Development Training". It is never called a certification or endorsement.
- Cognia eleot® Observer Certification is shown as **Pending** until it is awarded.
- Only features shipped at launch: video lessons, notes, practice, homework, topic quizzes, skill report, dashboard. No mock exams and no Foundation Program until they exist.

## Assets (`apps/landing/assets/`, source of truth for the app too)

| File | Use |
|---|---|
| `logo-mark.svg` | A∫E on light grounds (navy A/E, steel `#2F6FAD` integral) |
| `logo-mark-reverse.svg` | A∫E on navy (white A/E, baby-blue integral) |
| `icon.svg` / `icon-maskable.svg` | App icon: mark on a navy rounded square / full-bleed navy (maskable safe zone) |
| `portrait.webp` | Background-removed, waist-up cutout of the supplied portrait (poster text, third-party badge and belt buckle removed). Low resolution (532×690); replace with an original high-res photo when available |

## App palette (replaces `AppLightPalette` / `AppDarkPalette` values; roles unchanged)

Contrast checked: every text pair is ≥ 4.5:1.

| Role | Light | Dark |
|---|---|---|
| background | `#FFFFFF` | `#0B1724` |
| surface | `#F4F9FC` | `#102233` |
| raised | `#FFFFFF` | `#16293C` |
| line | `#D6E4EE` | `#22384D` |
| lineStrong | `#B7CCDC` | `#2F4A63` |
| ink | `#15202B` | `#EAF3F9` |
| inkSecondary | `#44586C` | `#A9BFD1` |
| inkTertiary | `#5B6F83` | `#8BA3B8` |
| brand | `#102A43` | `#B8E0F6` |
| onBrand | `#FFFFFF` | `#102A43` |
| brandWash | `#E6F4FC` | `#15324A` |
| brandLine | `#4A90C8` | `#5C9BD1` |  (focus ring: ≥ 3:1 on every ground)
| scrim | `#7A102A43` | `#99000000` |
| shadow | `#1A102A43` | `#33000000` |
| examBar | `#0B1F33` | `#0B1F33` |
| onExamBar | `#EAF3F9` | `#EAF3F9` |
| onExamBarVariant | `#A9BFD1` | `#A9BFD1` |
| examBarRule | `#24415E` | `#24415E` |
| examBarPrimary | `#B8E0F6` | `#B8E0F6` |

Correct / incorrect / warm / warning / danger keep their current values. `hue-blue` in `app_hues.dart` becomes `#2F6FAD`.

## App touchpoints

1. `lib/core/theme/app_palette.dart` and `app_hues.dart`: the values above.
2. A shared `BrandMark` widget (`lib/shared/widgets/brand_mark.dart`, `flutter_svg`, already a dependency) renders `assets/brand/logo-mark.svg` or the reverse by theme brightness. It is used in `shell_header.dart` next to the existing name + "SAT & EST Math" lines, and on the auth screens' header.
3. `lib/app.dart` title: `Abdelrahman Elmenshawy | SAT & EST Math`.
4. `web/index.html` (title, description, apple title), `web/manifest.json` (name, short name "Elmenshawy", description, `#102A43` colours), `web/favicon.png`, `web/icons/*`.
5. Android `mipmap-*/ic_launcher.png` and iOS `AppIcon.appiconset/*`, rendered from `icon.svg` / `icon-maskable.svg` at each required size.
6. Re-baseline all goldens (`flutter test --update-goldens`) and review a sample in light and dark.
7. DESIGN.md is regenerated from the shipped world after the change (impeccable documenter).

## Landing page

Built and reviewed under impeccable. Its direction contract lives in `.impeccable/surfaces/apps-landing-index-html.md`. Deploy is a separate Cloudflare Pages project with `apps/landing` as the root and no build step. `APP_ORIGIN` in `apps/landing/main.js` and the `href`s in `index.html` point at the app (`https://sat-prod.pages.dev` until the domain, Q-01, is decided).

## Non-goals

No guest catalogue, no prices, no purchase UI, no intro video (the script exists in the brief; record it later).
