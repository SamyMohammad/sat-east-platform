# F-4 — Design gallery — design

Status: approved 2026-10-15. Parent: [`2026-10-13-f4-design-system-questionview-design.md`](2026-10-13-f4-design-system-questionview-design.md) step 6 and the "PR Gallery" entry in `docs/superpowers/plans/2026-10-13-f4-design-system.md`. Tier **M** (`docs/15` §2): one presentation-only feature, no backend.

## Goal
A `/gallery` page, hidden in prod, that shows every `QuestionView` mode and state from static sample data. The user and the teacher review it on staging at 360 and 1280 against the Claude Design export. Merging it closes the UI part of Phase 0 (`docs/15` §1 row 6).

## Decisions (2026-10-15)
| Topic | Decision |
|---|---|
| Interactivity | Static catalogue. Each entry is a frozen `QuestionView`, callbacks are no-ops, and nothing changes state. |
| Scope | `QuestionView` only. The smaller components already have goldens and are not repeated. |
| Shape | Full-screen viewer at the real window width, outside the app shell. Width is checked by resizing the browser or using Chrome device mode. |
| Deploy | Already in place: CI deploys every `main` push to Cloudflare Pages with `FLAVOR=staging`. No deploy work. |

## 1. Files (`lib/features/design_gallery/presentation/`)
```
gallery_entries.dart   GalleryEntry {id, label, build(BuildContext), openOverlay?(BuildContext)}
                       const-ordered list `galleryEntries`; static sample data
gallery_screen.dart    GalleryScreen(entryId): top bar + selected entry
```
- Presentation only: no `data/` or `domain/` layer, because there is no data source (ADR-007 §4, CLAUDE.md A.1).
- **Sample data** comes from the export (`QuestionView.dc.html` QS):
  - the linear equation `3x − 7 = 29`;
  - the rational expression;
  - the SPR slope question;
  - one explanation with an Arabic paragraph (rule 8).
- **Quiz values:** "Quiz 4.2", 12 questions, `timeBudget` 18:00, `warnAt` 5:00.
- **Entries (17), with ids:**
  - **Practice:** `practice-idle`, `practice-checking`, `practice-first-miss`, `practice-correct`, `practice-revealed`, `practice-revealed-spr`.
  - **Homework:** `homework-saved`, `homework-saving`, `homework-offline`, `homework-failed`, `homework-navigator`.
  - **Quiz:** `quiz`, `quiz-warning`, `quiz-timer-hidden`, `quiz-navigator`, `quiz-submit`, `quiz-time-up`.
- **Overlay entries** (`homework-navigator`, `quiz-navigator`, `quiz-submit`, `quiz-time-up`) have `openOverlay`, which calls the public helpers:
  - `showHomeworkNavigatorSheet` on phone (on wide, the panel is already visible);
  - `showNavigatorSheet` / `showNavigatorPopover`;
  - `showSubmitConfirmDialog`;
  - `showQuizTimeUpDialog`.

## 2. Screen
- **Top bar** (`AppBar`, English copy):
  - title "Design gallery";
  - a `DropdownButton` of entry labels;
  - previous / next `IconButton`s (tooltips "Previous entry" / "Next entry"), disabled at the ends;
  - a "Reopen" `TextButton`, shown only for overlay entries.
- **Body:** the entry's `QuestionView`, filling the rest of the screen.
- **State:** the URL is the only state.
  - The dropdown and prev/next call `context.go('/gallery?entry=<id>')`.
  - A missing or unknown id shows the first entry.
  - No Cubit, because there is no business state (B.1).
- **Overlays:**
  - A small `StatefulWidget` runs `openOverlay` after the first frame (`addPostFrameCallback`) when the entry changes.
  - Before opening, it pops any `PopupRoute` left from the previous entry.
  - "Reopen" runs it again.
  - This local UI state is allowed by B.1.

## 3. Routing (`lib/core/router/app_router.dart`)
- `createRouter({String? initialLocation, bool? includeGallery})`. The route is registered only when `!Env.isProd && (includeGallery ?? true)`; `Env.isProd` is a compile-time const, so prod builds drop the gallery code.
- `AppRoutes.gallery = '/gallery'` is a top-level `GoRoute` outside the `StatefulShellRoute`, so it has no nav chrome.

## 4. Testing (`test/features/design_gallery/`)
- Every entry renders at 360×800 and 1280×800 with `tester.takeException() == null`.
- The dropdown and prev/next change the shown entry and the `entry` query parameter. Prev is disabled on the first entry and next on the last.
- Each overlay entry opens its overlay after the first frame. "Reopen" opens it again after it is closed. Switching entry closes a leftover overlay.
- An unknown id shows the first entry.
- `createRouter(includeGallery: false)` cannot resolve `/gallery`; `true` can.
- No new goldens: `QuestionView` already has 61.

## Done when
`dart format`, `flutter analyze --fatal-infos` and `flutter test` are clean. CI is green and the branch is merged, so CI deploys it to staging. `https://sat-staging.pages.dev/#/gallery` is checked at 360 and 1280. `docs/15` row 6 is marked done and `docs/STATUS.md` is updated.
