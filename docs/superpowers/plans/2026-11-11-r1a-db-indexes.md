# R1a — DB indexes + cron history purge

## Context

Roadmap R1 (docs/STATUS.md, PR #80). Prod targets 2,000 students / 300 concurrent. A migration audit found 46 foreign-key columns with no index led by that column, an every-minute cron (`expire-attempts`) scanning `attempts` with no matching index, and `cron.job_run_details` growing ~1,440 rows/day forever (Supabase docs confirm pg_cron never prunes it, and a huge table can break Postgres upgrades).

Dropped from R1 scope after checking the code: rewriting per-row RLS on `topic_assets` / notes storage. The only direct client read of `topic_assets` filters by `topic_id` + `kind` (`apps/client/lib/core/di/injection.dart:445`), and storage reads fetch one object by name, so the policy runs on a handful of rows. The fix there is the `topic_assets(topic_id)` index below, not a policy rewrite. Rate-limit rollback and k6 load tests are separate stories (R1b, R1c).

Outcome: no behaviour change; every FK has a leading index, enforced by a test so future migrations can't regress.

## Changes

### 1. Migration `supabase/migrations/20261107100000_r1a_fk_indexes.sql`

Header comment: `-- R1a / NFR-01, NFR-02: FK indexes, expire-cron index, cron history purge. From templates/setting.sql + rpc.sql.`

**a. FK indexes** — one plain `create index if not exists <table>_<column>_idx on <schema>.<table> (<column>);` per column below (plain, not `concurrently`: migrations run in a transaction and tables are small).

```
courses.owner_id            prices.course_id            coupons.course_id
orders.course_id            orders.price_id             orders.coupon_id
activation_codes.course_id  activation_codes.created_by activation_codes.redeemed_by
enrollments.course_id       enrollments.order_id        enrollments.activation_code_id
units.course_id             topics.unit_id              subtopics.topic_id
topic_assets.topic_id       topic_assets.subtopic_id    video_chapters.asset_id
video_chapters.subtopic_id  subtopic_skills.skill_id    questions.subtopic_id
question_courses.course_id  question_skills.skill_id    mock_templates.course_id
mock_results.template_id    official_scores.course_id   attempts.course_id
attempts.topic_id           attempts.mock_form_id       attempt_questions.question_id
topic_progress.topic_id     topic_progress.homework_attempt_id  topic_progress.unlocked_by
video_progress.asset_id     question_exposure.question_id  skill_mastery.skill_id
mistake_notebook.question_id  live_sessions.course_id   live_sessions.recording_asset_id
ai_threads.question_id      ai_threads.attempt_id       escalations.live_session_id
announcements.course_id     audit_log.actor             question_reports.resolved_by
skill_mastery_daily.skill_id  question_reports.question_id
```
All are `public.*`. `question_reports.question_id` only has a partial unique index (`status='open'`), so it gets a full one too. Source of each FK: `20261006235113_f2_schema.sql`, plus `20261029100000_c6_review_queue.sql:19` and `20261103100000_anl01_mastery.sql:17`.

**b. Expire-cron index** — matches `private.expire_overdue_attempts()` (`20261018100000_lane2a_expire_cron.sql:21-24`, `where kind='quiz' and status='in_progress' … order by started_at, id`):
```sql
create index if not exists attempts_quiz_in_progress_idx
  on public.attempts (started_at, id) where kind = 'quiz' and status = 'in_progress';
```

**c. Cron history purge** — new tunable (rule 5), copied from `supabase/templates/setting.sql`:
```sql
insert into public.settings (key, value) values ('cron_history_keep_days', '7'::jsonb)
on conflict (key) do nothing;
```
Then `create or replace function private.nightly_cleanup()` — the exact body from `20261018100000_lane2a_expire_cron.sql:46-62` plus one statement at the end:
```sql
delete from cron.job_run_details d
where d.end_time < pg_catalog.now() - pg_catalog.make_interval(days => private.setting_int('cron_history_keep_days'));
```
Keep `security definer`, `set search_path = ''`, and re-issue `revoke execute … from public, anon, authenticated;`. The key stays out of `teacher_update_settings`' allow-list (hidden, like `practice_stale_h`). No schedule change: `nightly-cleanup` already runs at 02:00.

### 2. Test `supabase/tests/49_r1a_indexes.test.sql` (from `supabase/templates/test.sql`, test names prefixed `R1a:`)

- **FK invariant:** for every `pg_constraint` with `contype='f'` whose table is in `public` or `private`, there exists a non-partial index (`indpred is null`) on that table whose first key column (`indkey[0]`) equals the FK's first column (`conkey[1]`). Assert the set of violators is empty and print violators in the failure message (`is_empty` on a query returning `table.column`).
- **Partial index:** `attempts_quiz_in_progress_idx` exists on `public.attempts`.
- **Setting:** `cron_history_keep_days` = 7.
- **Purge:** as postgres, insert into `cron.job_run_details` one row with `end_time = now() - interval '8 days'` and one with `end_time = now() - interval '1 day'` (tagged by a unique `command` text); call `private.nightly_cleanup()`; assert old row gone, recent row kept.
- **Privilege:** `has_function_privilege('authenticated','private.nightly_cleanup()','execute')` is false.

Existing `supabase/tests/18_expire_cron.test.sql` must still pass unchanged.

### 3. Docs

- `docs/07-backend-logic-and-api.md:106` (`cron-*` row): add to the nightly-cleanup description "delete `cron.job_run_details` rows older than `cron_history_keep_days` (default 7)".
- `docs/STATUS.md` is updated by the router after merge (not part of the implementation task).

## Execution

- Branch `perf/r1a-db-indexes` off `main`, own worktree.
- Codex via `codex-delegate` (`relay-failover.mjs`, background): brief points at the plan copy, tests first (task 2 before task 1), scope = the migration, the test file and the two docs only; do not touch other migrations, client code or CI; do not commit.
- Router review: `git diff --stat`, read hunks, then gates myself; commit, push, PR titled `perf(db): R1a FK indexes + cron history purge (NFR-01, NFR-02)`.

## Verification

- CI `db` job (source of truth — local `supabase start` crashes with 139): applies all migrations on a fresh DB, `supabase test db` (all 49 files green), `supabase db lint --fail-on error`, private-schema REST check, demo seed twice.
- Locally if Docker cooperates: `scripts/db-reset.ps1` then `scripts/db-test.ps1`; otherwise rely on the draft PR's CI run.
- After staging deploy (auto on merge): `explain` the expire query via Supabase MCP `execute_sql` on staging and confirm it uses `attempts_quiz_in_progress_idx`; `select count(*) from cron.job_run_details` drops after the next 02:00 run.
