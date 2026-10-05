# ADR-007: State management (Cubit/Bloc) and client repo layout

**Status:** Proposed · **Date:** 2026-10-05 · **Deciders:** Developer

## Context
`docs/05` §2 leaves state management open ("Riverpod or BLoC — developer's choice, be consistent").
Backlog F-1 asks for a monorepo (`apps/client`, `packages/core`) while `docs/05` §3 shows a single
`lib/` tree. Both need one answer before the first line of Dart is written.

The developer's AI tooling (skills `flutter-feature`, `flutter-code-quality:*`, agents
`test-writer`, `code-reviewer`) all assume Cubit/Bloc with sealed states, `bloc_test` and `get_it`.

## Decision
1. **Cubit by default, Bloc only where events matter** (exam engine timer/navigation, attempt
   autosave queue). Sealed state classes, `BlocSelector` for narrow rebuilds, `bloc_test` for tests.
2. **DI:** `get_it` — lazy singletons for services/repos, factories for cubits.
3. **Networking:** `supabase_flutter` is the only backend client. Data sources wrap
   `SupabaseClient` (`.rpc()`, `.functions.invoke()`, `.from()`), not Dio. Repositories return
   `Result<T>` (success/failure) and map Postgres/EF errors to the error codes in `docs/07` §9.
4. **Layout:**
   ```
   apps/client/                 # Flutter app (web + Android + iOS), flavors dev/staging/prod
     lib/core/                  # theme, router (go_router), env, errors, di, math_render, secure_screen
     lib/features/<feature>/{data,domain,presentation}
     lib/shared/widgets/        # QuestionView lives here (used by 4 features)
   packages/core/               # pure Dart: SPR grader mirror, entities shared with tools (add only when needed)
   supabase/                    # migrations/, functions/, tests/, seed.sql
   tools/content-pipeline/      # Python (docs/09)
   docs/
   ```
   Folder names inside a feature follow the `flutter-feature` skill (`datasources/`, `models/`,
   `repos/`, `entities/`, `usecases/`, `bloc/`, `screens/`, `widgets/`).
5. Skip a use case when it only forwards to a repository (per `flutter-code-quality:architecture`).

## Options considered
| Option | Pros | Cons |
|---|---|---|
| Cubit/Bloc + get_it (chosen) | Matches all installed skills/agents; explicit, testable; good for exam state machine | More boilerplate than Riverpod |
| Riverpod | Less boilerplate, compile-safe DI | Tooling/skills would fight it; mixing patterns violates "be consistent" |

## Consequences
- Every Cubit public method gets a `bloc_test` for success and failure paths.
- `packages/core` starts empty; create it only when the pipeline or a second app needs shared Dart.
- Revisit only if a second developer joins with a strong Riverpod preference.
