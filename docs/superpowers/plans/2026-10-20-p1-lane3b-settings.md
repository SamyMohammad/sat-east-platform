# Lane 3b — teacher settings (C-7, ADM-06) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

Today the teacher can only change tunables (pass mark, cooldown, device limit, quiz size and timing, access window) through SQL. 3b adds a Settings screen to the teacher shell. "Settings" is already in the nav, disabled, since #40. The server owns the allowed keys and their ranges, so the client hardcodes no ranges (rule 5) and can never save an out-of-range value (rule 2).

**Spec:** `docs/superpowers/specs/2026-10-19-p1-lane3-teacher-builder-design.md` §Goals 4, D5 (approved; no pool-split key exists).
**Worktree:** `C:/Users/Lenovo/sat-wt-lane3`, branch `feat/P1-lane3b-settings` (from `main` at `3c5a7e0`).
**Implementer:** Codex through `codex-delegate`, same session `01a1557a-7e72-78d2-b2a5-621c59f92d2c` (it wrote 3a). Claude runs the Flutter gates; CI runs pgTAP on a draft PR.

## Global constraints

- CLAUDE.md rules 1–10, A, B; `docs/16` §2; SQL from `supabase/templates/`.
- Reserved:
  - Migration `20261020100000_lane3b_settings.sql`.
  - pgTAP `33_teacher_settings.test.sql`.
  - Route `/teacher/settings`.
  - Folder `lib/features/teacher/settings`.
- No new error code: `invalid_input` and `forbidden` are reused.
- Append-only edits to DI and the router. `dart format` only touched files. Non-ASCII literals are written as `\u` escapes.

## Editable keys (server allow-list, `private.teacher_setting_spec()`)

| Group | Key | Label | Unit | Min | Max |
|-------|-----|-------|------|-----|-----|
| Quiz | `pass_mark` | Pass mark | % | 1 | 100 |
| Quiz | `cooldown_h` | Retake cooldown | hours | 0 | 168 |
| Quiz | `quiz_size` | Questions per quiz | questions | 1 | 60 |
| Quiz | `quiz_time_per_q_s` | Time per question | seconds | 15 | 600 |
| Quiz | `quiz_warn_s` | Time warning at | seconds left | 0 | 1800 |
| Practice | `practice_min` | Practice before quiz | questions | 0 | 50 |
| Practice | `homework_size` | Homework size | questions | 1 | 60 |
| Practice | `review_max` | Review set max | questions | 1 | 30 |
| Practice | `review_per_skill` | Review per skill | questions | 1 | 10 |
| Access | `access_grace_days` | Days after test date | days | 0 | 60 |
| Access | `access_min_days` | Minimum access | days | 1 | 365 |
| Access | `test_date_max_days` | Latest test date | days ahead | 30 | 730 |
| Devices | `device_limit` | Devices per student | devices | 1 | 5 |
| AI | `ai_daily_cap` | AI questions per day | per day | 0 | 200 |

All values are integers. There is one cross-field rule: `quiz_warn_s` < `quiz_size` × `quiz_time_per_q_s`, checked against the values **after** the update.

## Review focus

1. A student and anon get `forbidden` / no execute on both RPCs.
2. Saving is all-or-nothing. If any key is unknown, non-integer or out of range, or the cross-field rule fails → `invalid_input`, and **no** key changes (pgTAP checks the row values after the failure).
3. Keys outside the allow-list (`currency_by_country`, `rate_*`, …) can't be written even by the teacher.
4. Each saved key writes one `audit_log` row (`settings.update`, `entity`=key, `diff` before/after) and updates `settings.updated_at`.
5. Client: only changed keys are sent; the per-field range shown in the UI comes from the server spec; there is no hardcoded min/max in Dart.

---

### Task 0: Land the plan (Claude)
- [ ] Copy this plan to `docs/superpowers/plans/2026-10-20-p1-lane3b-settings.md` and commit it.

### Task 1: Backend (Codex)

**Create:** the migration, `supabase/tests/33_teacher_settings.test.sql`.
**Modify:** `docs/07` (RPC rows).

- `private.teacher_setting_spec()` returns `table(key text, grp text, label text, unit text, min int, max int, sort int)`, holding the table above. It's revoked from everyone.
- `public.teacher_get_settings()` returns `[{key, group, label, unit, min, max, value}]` in `sort` order. It is teacher-only and joins `public.settings`.
- `public.teacher_update_settings(p_values jsonb)` returns `{ok:true, updated:[keys]}`.
  - It is teacher-only.
  - It validates every pair first, then applies them all.
  - It writes an audit row per key.
  - An empty object → `{ok:true, updated:[]}`.

- [ ] **Step 1: pgTAP first**: Review focus 1–4. Also the happy path (2 keys changed, others untouched), each boundary (min and max OK; min−1 and max+1 rejected), a string or float value rejected, and the cross-field rule.
- [ ] **Step 2: Implement.**
- [ ] **Step 3 (Claude):** push, open a draft PR, CI `db` green.

### Task 2: Settings screen (Codex, after Task 1)

**Create** `lib/features/teacher/settings/{data,domain,presentation}` (mirror `lib/features/teacher/course_builder/**`):
- `SettingSpec` entity (`key`, `group`, `label`, `unit`, `min`, `max`, `value`).
- `TeacherSettingsRepository`: `load()`, `save(Map<String,int> changed)`.
- `TeacherSettingsCubit`: `load()`, `edit(key, int?)`, `save()`, `discard()`. States: `Loading`, `Loaded(specs, edits, saving, lastError?, savedAt?)`, `Failed`. `save()` sends only the keys whose edit differs from the value, then reloads.
- `TeacherSettingsScreen` inside `TeacherShell`:
  - One card per group with an integer `TextField` per key. Each field shows the label, the unit suffix and the helper "{min}–{max}".
  - Inline error "Enter a whole number from {min} to {max}" (UX only).
  - A "Save changes" bar, shown only when something is dirty, with "Discard".
  - On success, the SnackBar "Settings saved"; on `invalid_input`, "Some values are out of range. Nothing was saved."
  - Controllers are created in `initState` and disposed (B.7).

**Modify:**
- `TeacherShell`: enable "Settings" → `/teacher/settings` and mark it selected on that route.
- The router: add `/teacher/settings` under the existing teacher gate.
- DI: append.

- [ ] **Step 1: Tests first**:
  - Model parsing.
  - Repository error mapping.
  - Every cubit method on success and failure, including "only changed keys sent" and discard.
  - Widget tests: groups render, the helper range comes from the spec, the inline error, the Save bar appears only when dirty, the success and failure SnackBars, and no overflow at 360 / 1280.
  - Router: a student going to `/teacher/settings` lands on `/`.
- [ ] **Step 2: Implement.**

### Task 3: Gates, review, PR (Claude)
- [ ] `dart format --set-exit-if-changed .`, `flutter analyze --fatal-infos`, `flutter test -j 2 --exclude-tags golden` + `--tags golden`.
- [ ] Read the diff against Review focus 1–5.
- [ ] STATUS: the 3b row → PR, 3c next. Commit by path, push, mark ready: "feat(P1): teacher settings (C-7, ADM-06)".
- [ ] Staging check in Chrome (after merge, with the same role toggle as 3a): change `pass_mark` 75 → 80 → back to 75; try 150 → error, nothing saved.

## Verification

- CI: `db` (pgTAP 33) + `client` green; local gates green.
- Staging: the steps above, plus a SQL `select key, value from settings where key='pass_mark'` before and after.
