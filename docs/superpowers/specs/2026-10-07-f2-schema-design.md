# F-2 row 2b — Starting schema + settings seed (design)

Story: docs/15 §1 row 2b (F-2). Source of truth: `docs/06-data-model.md` (§§2–3, conventions, §6).

## Goal
Every later feature reads the same tables. Ship the starting schema from `06` close to verbatim,
plus the `settings` table with its default values, without opening any data to the API yet.

## Scope
**In:**
- All enums (06 §2) and all tables (06 §3) in `public`.
- `private.question_keys`, `private.video_keys`, `private.rate_limits`.
- Indexes from 06 §5.
- `private.set_updated_at()` trigger function + a `before update` trigger on every table with `updated_at`.
- Sign-up trigger: `auth.users` insert → `public.profiles` row (06 conventions).
- `settings` seed with the 9 keys in 06 §6.
- pgTAP tests (below).

**Out (row 3):** grants to `anon`/`authenticated`, RLS policies, `is_teacher()`, `has_access()`,
CI gate "no public table without a policy". **Out (later stories):** RPCs, rate-limit helper,
other tunables.

## Decisions (agreed 2026-10-07)
1. **Locked until row 3.** RLS is on for every public table (hardening Layer 2 + explicit
   `enable row level security`), no grants, no policies. `service_role` gets table grants so Edge
   Functions and seed scripts work (it bypasses RLS anyway).
2. **FK deletes:** to `profiles` → `cascade`; to content/catalogue → `restrict`.
3. **Not null** per 06 conventions.
4. **Sign-up trigger** is `security definer`, `set search_path = ''`, in `private`; `role` never
   comes from metadata; `full_name` = metadata `full_name`, else e-mail local part.
5. **Two migrations:** `<ts>_schema.sql` (enums, tables, indexes, triggers) and
   `<ts>_settings_seed.sql` (`on conflict (key) do nothing`).

## Files
| File | Content |
|------|---------|
| `supabase/migrations/<ts>_schema.sql` | enums → identity → catalogue/commerce → content → question bank (+ `private.question_keys`) → progress/attempts → mocks → AI/comms/ops (+ `private.rate_limits`, `private.video_keys`) → indexes → triggers |
| `supabase/migrations/<ts+1>_settings_seed.sql` | 9 settings rows |
| `supabase/tests/03_schema_tables.test.sql` | every table in 06 exists; key columns/PKs; `private` tables not in `public` |
| `supabase/tests/04_schema_locked.test.sql` | every public table has RLS on; `anon`/`authenticated` have no table privilege on any public or private table |
| `supabase/tests/05_schema_triggers.test.sql` | sign-up creates profile (metadata name, fallback, role forced to student); `updated_at` bumps on update; FK cascade from profile delete |
| `supabase/tests/06_settings_seed.test.sql` | 9 keys with their defaults |

## Error handling
Schema only; no RPCs, so no `docs/07` §9 codes yet. The sign-up trigger must not fail sign-up on a
missing name (fallback covers it).

## Testing / done
`scripts/db-reset.ps1` + `scripts/db-test.ps1` green; `supabase db lint` and advisors show no new
findings except the expected "RLS enabled, no policy" notices (resolved in row 3); review
checklist (`supabase/templates/README.md`) walked.

## Risks
- 06 sketches omit types for some columns (`created_at`, `answered_at` …) → `timestamptz`,
  `not null default now()` for `*_at` creation stamps, nullable for event stamps.
- `mock_forms.question_ids uuid[]` has no FK (array) — accepted; integrity checked by the mock
  builder later.
