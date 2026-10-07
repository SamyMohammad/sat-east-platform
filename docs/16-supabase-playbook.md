# 16 — Supabase Playbook: Known Drawbacks → Practical Mitigations

> Companion to [ADR-001](adr/ADR-001-stack-flutter-supabase.md). Supabase is the right backend for
> this project, but it has 10 real weaknesses. Each one below has a concrete, buildable mitigation
> and the phase/task where it lands. Developer profile assumed: strong Flutter, new to SQL —
> so SQL is written from fixed templates and **tests, not expertise, guarantee correctness**.

| # | Drawback | Mitigation (one line) | Lands in |
|---|----------|-----------------------|----------|
| 1 | One RLS mistake = data leak | `private` schema + auto-RLS trigger + revoke-by-default + CI gate | Phase 0, first migration |
| 2 | SQL / plpgsql / TS learning curve | 5 templates + review checklist + shared test fixtures + learning track | Phase 0 |
| 3 | No built-in offline sync | Outbox pattern (`hive_ce`) + idempotent `save_answer` + server deadline | S4 |
| 4 | No push / crash / analytics | Sentry + PostHog + FCM (ADR-008) | Phase 0 (F-5), push in Phase 2 |
| 5 | No App Check | Firebase App Check on sensitive EFs + Turnstile captcha + Postgres rate limits | S1 / S3 |
| 6 | Local Docker is heavy | Start only needed services + WSL memory cap + scripts | Phase 0 |
| 7 | Free projects pause | 3 environments (local / staging-free / prod-Pro) + keep-alive cron | Phase 0 (F-2, F-3) |
| 8 | Edge Function limits / cold starts | Heavy logic in Postgres; 3 "fat" functions; streaming; batching | S1+ |
| 9 | SMS OTP needs a provider | Defer; email + Google first; SMS hook later | P2 |
| 10 | Vertical scaling only | Indexes, materialized views via pg_cron, perf test on `submit_attempt` | S4 / S5 |

---

## 1. RLS mistakes — four layers so one mistake is not a leak

**Layer 1 — `private` schema for secrets.** PostgREST only exposes schemas listed in
`supabase/config.toml` → `[api] schemas`. `private` is never listed, so even a missing policy cannot
expose it over the API.

```sql
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
-- question_keys, rate_limits, materialized views and RPC-internal helpers live here.
```
> Checked by `scripts/api-private-check.ps1` (expects 406 for `Accept-Profile: private`).

> **Exception — RLS policy helpers stay in `public`.** Policy expressions run as the querying role,
> so a policy calling `private.is_teacher()` would fail with "permission denied for schema private".
> `public.is_teacher()` and `public.has_access(course_id)` are `security definer`, read only the
> caller's own data, and get `grant execute ... to authenticated`. Everything a `security definer`
> RPC calls internally may live in `private`.

**Layer 2 — auto-enable RLS on every new `public` table** (fail closed: a forgotten policy blocks
access instead of opening it).

```sql
create or replace function private.rls_auto_enable()
returns event_trigger language plpgsql security definer set search_path = '' as $$
declare cmd record;
begin
  for cmd in
    select * from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
      and object_type = 'table' and schema_name = 'public'
  loop
    execute format('alter table %s enable row level security', cmd.object_identity);
  end loop;
end $$;

create event trigger ensure_rls on ddl_command_end
  when tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
  execute function private.rls_auto_enable();
```
> Verify in Phase 0 that the hosted `postgres` role may create event triggers. If not, Layer 4 still catches it.
>
> **Scope of Layers 2–3:** they cover objects created by `postgres`, which is the role every migration
> runs as. DDL run as `supabase_admin` (superuser) skips the event trigger (supautils), and that role's
> own default grants give anon/authenticated full table access. So never make schema changes as
> `supabase_admin`. `alter table … set schema public` also skips the trigger. Layer 4 is the backstop
> for both.

**Layer 3 — functions, tables and sequences are not reachable unless granted.** By default every new
function is executable by `PUBLIC` (so by `anon` and `authenticated`), and Supabase auto-grants new
`public` tables to the API roles. Turn that off once, then grant per object.
Verified in F-2: a per-schema `revoke … from public` alone does **not** work. Postgres's
EXECUTE-to-PUBLIC is a *global* default, and per-schema defaults can only add to it. So the revoke
must be global (`supabase/tests/02_hardening_default_privileges.test.sql` proves it).

```sql
-- functions: global PUBLIC revoke + Supabase's per-schema API-role grants (service_role keeps its grant)
alter default privileges for role postgres
  revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;
-- tables / sequences: same as Supabase's hosted default from 2026-10-30
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;
-- per RPC / table:
grant execute on function public.submit_attempt(uuid) to authenticated;
```
> Keep `supabase/config.toml` `auto_expose_new_tables` at its default. Setting it to `false` locally also
> revokes `service_role`'s EXECUTE on functions, which hosted projects do not do. Local would then drift
> from staging/prod. The migration alone gives the same fail-closed result everywhere.

**Layer 4 — CI gate (pgTAP).** Fails the build if any `public` table lacks RLS or a policy.
Use [`supabase_test_helpers`](https://github.com/usebasejump/supabase-test-helpers)
(`tests.create_supabase_user`, `tests.authenticate_as`, `tests.rls_enabled`).

```sql
select is_empty($$
  select c.relname from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and (not c.relrowsecurity
         or not exists (select 1 from pg_policies p
                        where p.schemaname = 'public' and p.tablename = c.relname))
$$, 'NFR-08: every public table has RLS enabled and at least one policy');

-- Views / materialized views cannot have RLS and are exposed by default → none allowed in public.
select is_empty($$
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('v','m')
$$, 'no views or materialized views in the public schema');
```
Plus `supabase db lint` and the Supabase **security advisors** checked every sprint.

---

## 2. SQL learning curve — templates, checklist, shared fixtures

**Templates** in `supabase/templates/` — every new SQL file starts as a copy of one of these:

| Template | Contains |
|----------|----------|
| `table.sql` | table + `enable row level security` + select-own / teacher-all policies + index |
| `rpc.sql` | `security definer`, `set search_path = ''`, `auth.uid()` check, `raise exception` with a code from `07` §9, explicit `grant execute` |
| `test.sql` | pgTAP: plan, two users (student A/B + teacher), "A cannot see B", "student cannot call teacher RPC" |
| `edge-function.ts` | Hono route, JWT → user, App Check check (§5), Sentry, `{error:{code,message}}` shape |
| `setting.sql` | `insert into settings(key, value) ... on conflict do nothing` for a new tunable |

**RPC template (core shape):**
```sql
create or replace function public.example_rpc(p_topic_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not public.has_access_topic(p_topic_id) then raise exception 'topic_locked'; end if;
  -- logic using fully-qualified names: public.topics, private.question_keys ...
  return jsonb_build_object('ok', true);
end $$;
revoke execute on function public.example_rpc(uuid) from public, anon;
grant  execute on function public.example_rpc(uuid) to authenticated;
```

**Review checklist (قائمة مراجعة لأي SQL — مش محتاج تكون خبير):**
1. الجدول الجديد في `public` ولا `private`؟ أي حاجة فيها إجابات أو أسرار لازم `private`.
2. فيه `enable row level security` وpolicy واحدة على الأقل؟
3. الـ policy بتقارن بـ `auth.uid()`؟ (من غيرها = كل الطلاب شايفين كل حاجة)
4. الدالة `security definer`؟ يبقى لازم `set search_path = ''` وأسماء كاملة (`public.x`).
5. الدالة بتتحقق من `auth.uid()` في أول سطر؟
6. فيه `grant execute ... to authenticated` بس (مش `anon`)؟
7. فيه رقم ثابت (pass mark، cooldown...)؟ لازم يتقري من `settings`.
8. فيه pgTAP test جديد، و`supabase test db` نجح؟

> Canonical English checklist (9 items, incl. table grants): `supabase/templates/README.md`.

**Shared fixtures — one rule, two implementations.** The SPR grader exists in SQL (real grading) and
Dart (input preview/validation). Both test suites read `supabase/tests/fixtures/spr_cases.json`
(rows from `08` §6 and `12` §2). If they disagree, CI fails.

**Learning track:** run `/anthropic-skills:deep-learner` with "Postgres for Supabase: RLS, plpgsql, pgTAP"
— week 1 RLS, week 2 functions, week 3 pgTAP — tied to the tasks you are building that week.
Use Supabase Studio (`http://localhost:54323`) to *see* tables and run queries while learning.

---

## 3. Offline — Outbox pattern for homework, quiz, mock

```
answer tapped → AnswerOutbox (hive_ce, survives reload) → SyncWorker → save_answer RPC
                     ▲ client_seq++                          │ on: connectivity, app resume, every 10 s
                     └──────────── ack removes item ◀────────┘
```
- **One `AttemptSyncService`** in `apps/client/lib/core/sync/`, used by `assessment` and `exam`.
- **Outbox store:** `hive_ce` (works on web via IndexedDB and on mobile). Key = `attempt_id:question_id`
  (only the latest answer per question is kept → the queue never grows unbounded).
- **Idempotent server:** `save_answer(..., client_seq)` upserts and **ignores** a write whose
  `client_seq` is older than the stored one. Duplicate or out-of-order retries are harmless.
- **Everything up-front:** `start_attempt` returns all questions; images are precached → once started,
  the attempt works fully offline.
- **Server time:** `start_attempt` returns `deadline` and `server_now`; client stores the offset and
  never trusts its own clock (NFR-05).
- **Deadline vs. offline — the explicit trade-off:**
  - *Homework* is untimed → nothing is ever lost; the outbox flushes whenever the student is back.
  - *Quiz / mock* are timed → the server accepts writes only until `deadline + settings.save_grace_s`
    (default 30 s, teacher can widen it). We never trust a client-sent `answered_at` (NFR-05), so an
    answer made in time but synced after the grace window is lost. The UI shows a red
    "offline — answers not saved yet" banner with a countdown so the student knows to reconnect.
- **Auto-submit:** the `cron-expire-attempts` job (every minute) submits and grades `in_progress`
  attempts past `deadline + grace`; `start_attempt`/`get_attempt_review` also do it lazily on read.
- **Second device / reinstall:** when `start_attempt` resumes an in-progress attempt it returns the
  saved answers **with their `client_seq`**; the client seeds its counter at `max + 1`, so a new device's
  writes are never discarded as "older".
- **Practice requires a connection** (keys are server-side) — acceptable.

---

## 4. Push, crashes, analytics — see ADR-008

- **Sentry:** `sentry_flutter` (web + Android + iOS, web source maps uploaded in CI) and the Deno
  SDK inside Edge Functions.
- **PostHog:** `posthog_flutter`, wrapped by one `AnalyticsService` (events from NFR-18). Swapping
  provider = one file.
- **FCM:** one Firebase project, used only for push + App Check. Sending from an Edge Function via
  FCM HTTP v1 with the service-account JSON stored as an EF secret. Tokens in `push_tokens`.

---

## 5. No App Check — layered abuse protection

| Layer | Protects | How |
|-------|----------|-----|
| Firebase App Check | Costly / sensitive EFs: `video-otp`, `pdf-url`, `ai-tutor`, `register-device` | Client sends `X-Firebase-AppCheck`; EF verifies the JWT against Firebase JWKS (`jose`). Web uses reCAPTCHA Enterprise. **Start in monitor mode** (log missing tokens), enforce after a week of clean logs. |
| Auth captcha | Bot sign-ups / credential stuffing | Cloudflare Turnstile — supported natively by Supabase Auth |
| Postgres rate limits | Question-bank scraping, AI cost | `private.rate_limits(key, window_start, count)` + `private.hit_rate_limit(key, max, window)`; called in `get_practice_questions`, `check_practice_answer`, `ai-tutor`; raises `rate_limited`. Limits in `settings`. |
| Server-side truth | Everything else | A student calling the API from Postman with their own token can do nothing the app can't — every rule is checked server-side (CLAUDE.md rule 2). |

Abnormal volume (e.g. > N practice fetches/day) also feeds SEC-04 suspicious-activity flags later.

---

## 6. Heavy local Docker — run only what you need

- Daily: `supabase start -x imgproxy,logflare,vector` (keep **Studio** — it's your SQL learning UI).
  Add `edge-runtime` to `-x` when not touching Edge Functions. Check names with `supabase start --help`.
- Cap WSL memory: `%UserProfile%\.wslconfig` → `[wsl2]` / `memory=6GB` (one-time, by you).
- Scripts in `scripts/`: `db-up.ps1`, `db-reset.ps1` (reset + seed), `db-test.ps1` (`supabase test db`), `db-down.ps1`.

---

## 7. Free projects pause — three environments

| Env | Where | Cost | Notes |
|-----|-------|------|-------|
| dev | local Docker | free | `supabase db reset` anytime |
| staging | Supabase free project | free | CI deploys migrations + EFs on merge to `main`; daily GitHub Actions cron hits the REST API to avoid the 7-day inactivity pause |
| prod | Supabase Pro + PITR | ~$25/mo + add-ons | Created before the closed beta (week 11) |

Staging is `sat-staging` in its own free Supabase org (the developer's other org already uses its
two free slots). CI (`.github/workflows/ci.yml`) runs on every PR and push; on `main` it deploys
migrations + Edge Functions to staging and the web build to Cloudflare Pages (ADR-009).
`keep-alive.yml` reads one row through REST every day.

The repo is private on GitHub Free, so branch protection is unavailable: CI is **advisory**.
Rule: never merge a PR whose checks are not green.

---

## 8. Edge Function limits — keep them thin

- **Rule:** grading, unlocking, scoring, analytics → Postgres functions. EFs only for secrets and
  third parties (Paymob, VdoCipher, LLM, email, FCM).
- **Three "fat" functions** (fewer cold starts, shared code):
  - `api` — Hono router: `/checkout`, `/redeem-code`, `/video-otp`, `/pdf-url`, `/register-device`, `/import-questions`, `/assemble-mock`
  - `payment-webhook` — isolated (public, HMAC-verified)
  - `ai-tutor` — isolated (streams SSE, LLM timeout, per-day cap)
- `EdgeRuntime.waitUntil()` for receipts/emails after responding to the webhook.
- **Question import in batches** of 200 per call with a progress bar in T-07 (no queue needed yet).

## 9. SMS OTP — deferred
Email + Google only at launch (AUTH-01). When needed: Supabase Auth **Send SMS Hook** with a cheap
provider, or WhatsApp OTP. Tracked as P2.

## 10. Scaling — measure first
- Indexes from `06` §5; enable `pg_stat_statements`; review advisors each sprint.
- Teacher matrix (ANL-05) and class insights (ANL-06) read from **materialized views in `private`**
  (materialized views can't have RLS), refreshed by `pg_cron` every 10 min (`refresh materialized
  view concurrently` → needs a unique index). Read only via the `teacher_matrix` /
  `teacher_class_insights` RPCs, which check `is_teacher()`.
- Performance test: seed a 44-question attempt and assert `submit_attempt` < 1.5 s (NFR-02) in CI.
- Connection pooling (Supavisor) is on by default; partition `attempt_answers` only past 50M rows.
