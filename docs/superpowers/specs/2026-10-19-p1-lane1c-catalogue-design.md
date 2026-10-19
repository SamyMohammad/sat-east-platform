# Lane 1c — catalogue + course page (P-1, PAY-01) — design

> Status: draft · 2026-10-19 · Branch `feat/P1-lane1c-catalogue`
> The user skipped the question round ("ابدأ"). Every decision below is the router's call unless marked **user**.

## Intent

A visitor or a signed-in student without a course can see which courses exist and what each one covers, so they can decide to buy (P-1). Today a student with no enrolment only sees "No course yet", which is a dead end.

## Current state

- The backend is done (PR #11, `20261009010000_pay01_catalogue.sql`):
  - `get_catalogue(p_country)` returns published courses with `topic_count`, `free_topic_slug` and `price {currency, amount_minor}`.
  - `get_course_page(p_slug, p_country)` returns the course, its units, the published topics in each unit (`slug`, `title`, `is_free_preview`, `subtopic_count`) and the `full` price. An unknown or unpublished slug raises `invalid_input`.
  - Both functions are granted to `anon` and `authenticated`. The currency comes from the profile country, then the hint, then `settings.currency_by_country.default`.
- `Env.enablePurchase` (`ENABLE_PURCHASE`) exists and is `false` in every env example.
- Design: `docs/design/claude-design-export/Public Pages.dc.html`, the "Courses" section and the course page.

## Goals

1. **Catalogue screen** (`/catalogue`): one card per published course with the title, the description, the topic count, the price (web purchase builds only) and "See the syllabus".
2. **Course page** (`/catalogue/:slug`): the title, the description, the syllabus grouped by unit with numbered topics (`1.1`, `1.2`, …) and the subtopic count, a **Free** badge on free-preview topics, and a price block.
3. Both routes are public. They are reachable signed out and signed in, on web and in the apps.
4. Entry points:
   - "Browse courses" on the sign-in screen.
   - A "Browse courses" action on the Courses tab's "No course yet" empty state.

## Non-goals

- The full S-01 landing page (hero, how it works, results, teacher bio, FAQ). It needs real content from the teacher.
- Payment, the Buy button and checkout (P-2/P-3, blocked on Q-03).
- **Free-topic access.** **user:** the free topic gets a badge only, and there is no "Try free" button. Opening a free topic without an enrolment is its own later story, because the earlier decision still holds: no course map without an active enrolment.
- The "Change country" picker, the bundle price and the access-window rule box. The rule box needs `settings` values; it lands with P-2.
- Any SQL change.

## Anti-goals

- Any price, buy button or purchase link in an app build (ADR-006, CLAUDE.md rule 7).
- Any route that leaks unpublished courses or topics. The server already filters them; the client must not add its own data.

## Decisions

| # | Decision |
|---|----------|
| D1 | The routes `/catalogue` and `/catalogue/:slug` are top-level, outside the shell. `_authRedirect` returns `null` for paths that start with `/catalogue` in `AuthSignedOut` and `AuthSignedIn`. Every other state keeps its current redirect. |
| D2 | The client sends `p_country = null` for now; the server picks the currency. There is no IP lookup. |
| D3 | The price shows only when `Env.enablePurchase` is true. It is formatted as `EGP 2,400`: `amount_minor / 100`, no decimals when they are zero, and a thousands separator. When `price` is null, the price row is hidden. |
| D4 | The course page CTA: "Have an activation code?" goes to `/activate` when signed in and to `/sign-up` when signed out. In app builds the copy is "Sign in or enter an activation code." (from the design). |
| D5 | The feature lives in `lib/features/catalogue/{data,domain,presentation}`. A `CatalogueRepository` exposes `getCatalogue()` and `getCoursePage(slug)` and returns `Result<T>`. There are two Cubits, `CatalogueCubit` and `CoursePageCubit` (factories in DI); no use cases (ADR-007 §5). |
| D6 | Errors: `invalid_input` on the course page shows a "Course not found" empty state with a "Browse courses" link. A network or unknown error shows `ErrorRetry`. An empty catalogue shows an empty state. |
| D7 | Course titles and descriptions use direction-aware text (CLAUDE.md rule 8), because the content may be Arabic. |
| D8 | Topic numbers are computed on the client from the order: unit index + topic index, 1-based. |

## Constraints

- CLAUDE.md A/B rules: layers, `Result<T>`, `isClosed` checks, `go_router` only, `const`, no codegen, layouts at 360 px and 1280 px.
- The router and DI are shared hotspots (STATUS). This lane only appends to them.
- Tests: data source mapping, the repository, every public Cubit method (success + failure), widget tests for both screens (loading, empty, error, data; price shown or hidden by the flag), and router redirect tests for the public paths in both auth states.

## Left to the builder

- Card and syllabus layout details, within the Booklet tokens and the design export.
- Whether the price formatter lives in the feature's presentation folder or in `lib/core` (it moves to `lib/core` only if a second feature needs it).
- Golden tests: optional, tagged `golden`.
