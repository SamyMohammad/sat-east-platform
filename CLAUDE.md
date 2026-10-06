# CLAUDE.md — SAT/EST Math Platform

Read `docs/README.md` first. Specs live in `docs/`; decisions in `docs/adr/`.

Daily workflow (per-story loop, Phase 0 order, which skill to use when): `docs/15-dev-workflow.md`.

## Stack
- Flutter (web + Android + iOS) single codebase, Clean Architecture, feature-first folders (`docs/05` §3).
- Client: Cubit/Bloc + get_it + go_router + `supabase_flutter` (no Dio); app lives in `apps/client/` — see ADR-007.
- Supabase: Postgres + RLS, Auth, Storage, Edge Functions (Deno/TypeScript), pg_cron.
- Migrations in `supabase/migrations/`; never edit prod schema by hand.

## Non-negotiable rules
1. **Answer keys never reach the client before submission.** Keys/explanations live in `private.question_keys` (non-exposed schema). Only `check_practice_answer`, `submit_attempt`, `get_attempt_review` return them.
2. Grading, unlocking, scoring, payments, enrollment, device registration → server-side (RPC / Edge Function). Never trust client-sent scores, amounts, or timers.
3. Every new table ships with RLS enabled and policies + a test in `supabase/tests/`.
4. Secrets (service role, Paymob, R2/VdoCipher, LLM, Desmos) only in Edge Function secrets.
   Secret data (answer keys, rate limits) and internal helpers live in the non-exposed `private` schema.
5. Tunable values (pass mark, cooldowns, pool split, device limit, blueprints, scale tables) come from the `settings` table — no magic numbers.
6. One shared `QuestionView` widget for practice, homework, quiz and mock.
7. Purchase UI only in the web build (`ENABLE_PURCHASE` flag) — see ADR-006.
8. UI copy is English. Content (notes, AI replies) may contain Arabic → support mixed-direction text.
9. New functions are not executable by default — every RPC gets an explicit `grant execute ... to authenticated`.
10. Every new SQL file starts from `supabase/templates/` and passes the review checklist in `docs/16` §2.

## Conventions
- Requirement IDs (e.g. `PRC-03`) from `docs/02-prd.md` in PR titles and test names.
- Error codes from `docs/07` §9.
- SPR grading rules and test table: `docs/08` §6 and `docs/12` §2 — keep tests in sync.

## A. Engineering rules
1. **Layers (MUST):** presentation → domain → data, never skipped or mixed. Presentation renders, handles interaction and observes state — zero business logic. Business logic in domain; Supabase/storage access in data. No new abstractions or patterns without a stated reason.
2. **Shared code:** anything used in 2+ features goes in `lib/core/` (logic, constants, extensions) or `lib/shared/widgets/` (UI, e.g. `QuestionView`). Search both before creating — never duplicate across features.
3. **Errors:** catch at the data boundary, flow up through every layer. Handle null, empty, loading and error states explicitly — no silent failures, no empty `catch`.
4. **Change discipline:** smallest change that solves the problem; fix root causes; no unrelated refactors; don't break existing APIs, flows or UX unless told to. Read the code before changing it and state assumptions when unclear.
5. **Dependencies:** justify every new package; latest stable, maintained, production-grade (check with `pub_dev_search`). Prefer the SDK or an existing dependency.
6. **Security:** no secrets in code or `env/*.json` — every `--dart-define` value ships inside the client (only the Supabase URL + anon key belong there). Never log tokens, answer keys, payment data or PII. Client-side validation is UX only; the server re-validates (rule 2). Flag security risks when you see them.
7. **Testing:** test domain, data and every public Cubit method (success + failure, ADR-007). Bug fixes start with a failing reproduction test. Deterministic tests only — no real network, no real timers (inject a clock), one behavior per test.
8. **Workflow (mandatory):** new feature → `/flutter-feature` first. Before calling a task done → `/flutter-code-quality:review-gate` (format/analyze/tests) then `/flutter-code-review`. After approval → `git-expert` agent for branch, commit and PR.
9. **Suggest agents proactively (MUST)** — don't wait to be asked:
   - `debugger` — any bug, crash, failing test or unexpected behavior.
   - `code-reviewer` — always offer it after `/flutter-code-review` passes, before the PR.
   - `test-writer` — code added or changed without tests. Test files are written by this agent (a project hook asks before any `*_test.dart` Write).
   - `git-expert` — branch, commit, PR, merge conflict, rebase.

## B. Flutter / Dart rules
1. **State:** Cubit by default, Bloc only where events matter (ADR-007) — no Riverpod/Provider/GetX. Cubits depend on use cases or domain repository interfaces (skip pass-through use cases, ADR-007 §5) — never on data sources or `SupabaseClient`. Check `isClosed` before emitting after an `await`; cancel stream subscriptions (Realtime, timers) in `close()`. `setState` only for local UI state, in the smallest widget.
2. **No code generation:** no `freezed`, `json_serializable` or `build_runner`. Use sealed classes + exhaustive `switch`, records, and hand-written `fromJson`/`toJson` in data models.
3. **Domain purity:** nothing under `domain/` imports `package:flutter/...` or `package:supabase_flutter/...`.
4. **Feature layout:** `lib/features/<feature>/{data,domain,presentation}` with inner folders per the `flutter-feature` skill (ADR-007 §4).
5. **Error contract:** data sources catch `PostgrestException` / `FunctionException` / `AuthException` and map them to `AppError` with a code from `docs/07` §9. Repositories return `Result<T>` (`Success` / `Failure`, `lib/core/errors/result.dart`). Presentation maps error codes to user-facing English copy — never show raw exception text.
6. **DI:** `get_it`, registered only in `lib/core/di/injection.dart` — lazy singletons for services/repos, factories for cubits. Never instantiate them by hand in widgets.
7. **Build discipline:** `const` wherever possible. Never create `TextEditingController`, `AnimationController`, `FocusNode`, `ScrollController` or streams in `build()`; create in `initState`, dispose in `dispose()`. No heavy work in `build()`. Small composed widgets; `BlocBuilder`/`BlocSelector` on the smallest subtree, never at the top of a screen.
8. **Navigation:** `go_router` only (`lib/core/router/`); no `Navigator.push` with ad-hoc routes.
9. **Layout & text:** check web at 360 px and 1280 px. Content text (notes, AI replies) uses direction-aware widgets (`Directionality` / `TextDirection` detection) — rule 8.

## Commands
Client (run from `apps/client/`; copy `env/<flavor>.example.json` to `env/<flavor>.json` first):
- `flutter run -d chrome --dart-define-from-file=env/dev.json` (web has no `--flavor`)
- `flutter run --flavor dev --dart-define-from-file=env/dev.json` (Android; flavors dev/staging/prod)
- `dart format .` · `flutter analyze --fatal-infos` · `flutter test`

Supabase (from repo root): `scripts/db-up.ps1` (`-Functions` to keep edge-runtime) · `scripts/db-reset.ps1` · `scripts/db-test.ps1` · `scripts/db-down.ps1`

## Dart/Flutter tooling
Per-story skill order is in `docs/15` §2; this section maps tools to tasks.

Dart MCP server (`dart-flutter` plugin) — add `apps/client/` as a root first (`roots` tool):
- Code: `analyze_files` (prefer over raw `flutter analyze` mid-task), `lsp` (hover / symbol search), `pub` (add/remove/get/outdated), `pub_dev_search`.
- Dependencies: read package source with `read_package_uris` / `rip_grep_packages` instead of guessing APIs.
- Running app (connect via `dtd` first): `hot_reload`, `hot_restart`, `get_runtime_errors`, `widget_inspector`, `flutter_driver_command` (tap / enter text / screenshot).

Library docs & GitHub:
- context7 MCP (`resolve-library-id` → `query-docs`) before writing code against any package API (bloc, go_router, get_it, supabase_flutter, supabase-js/Deno) or doing a version upgrade — don't rely on memory.
- GitHub via `gh` CLI (authenticated): `gh pr create`, `gh pr checks --watch`, `gh run view --log-failed`. No GitHub MCP needed.

Skills by task:
- Scaffold feature: `flutter-feature` · Cubit/Bloc: `flutter-code-quality:state-management` · architecture: `flutter-code-quality:architecture`.
- Tests: `dart-flutter:flutter-add-widget-test`, `dart-flutter:dart-add-unit-test`, `dart-flutter:flutter-add-integration-test`, `dart-flutter:dart-generate-test-mocks`, `flutter-design-fidelity:golden-tests`; `test-writer` agent for bloc/widget tests.
- Routing / JSON / l10n: `dart-flutter:flutter-setup-declarative-routing`, `dart-flutter:flutter-implement-json-serialization`, `dart-flutter:flutter-setup-localization`.
- Layout & UI: `flutter-code-quality:responsive-adaptive`, `dart-flutter:flutter-fix-layout-issues`, `flutter-code-quality:a11y-and-rtl` (mixed Arabic/English, rule 8), `flutter-design-fidelity:design-tokens` / `figma-to-widget` / `visual-verification`.
- Debugging: `dart-flutter:dart-fix-runtime-errors`, `dart-flutter:dart-resolve-package-conflicts`, `debugger` agent.
- Before commit/PR: `flutter-code-quality:review-gate`, then `code-reviewer` / `pr-reviewer` agents.
- Not for this project: `flutter-use-http-package` (we use `supabase_flutter`, no Dio/http), `flutter-webview-shell`, FFI skills.
