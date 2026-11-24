# Prod P2b: restore drill script + Free-limit watch

Spec: [prod readiness](../specs/2026-11-21-prod-readiness-design.md) §P2.4, §P2.5. Prod is not configured yet (no `PROD_*` vars); everything here must work on staging/local now and pick up prod automatically later.

## Task 1: `scripts/restore-drill.ps1`
Read `scripts/db-backup.sh` (the dump format, encryption, the restore comment at the top) and `docs/setup/prod.md` §7 first.
- Input: `-DumpFile <path to .dump.gpg>` (required for now; R2 download is optional: if `-R2Object` is given and `aws` + R2 env vars exist, download it first).
- Decrypt with `gpg` (passphrase from `$env:BACKUP_PASSPHRASE`, else gpg prompts). Never print the passphrase.
- Start a throwaway `postgres:17` Docker container on a random free local port (unique name, `--rm`), wait until ready, `pg_restore --no-owner --no-privileges` into it (create the roles/schemas the dump needs, e.g. `auth`, `storage`, `authenticated`, `anon`, `service_role`, or document which errors are expected and ignored, following §7's caveats).
- Sanity: print row counts for a fixed list of core tables (read migrations to pick: profiles, courses, questions, `private.question_keys`, attempts or equivalents) and fail if `questions`/`question_keys` are 0 or the restore exited with non-ignorable errors.
- Always clean up: stop the container and delete decrypted files in `finally`.
- Self-test path: `-SelfTest` switch that dumps the local Supabase DB (`scripts/db-up.ps1` running) with `pg_dump -Fc`, encrypts it with a throwaway passphrase, then runs the drill on it. Run it once and paste the output (counts) in the report.
- Update `docs/setup/prod.md` §7 to point at the script (short).

## Task 2: Free-limit watch in `.github/workflows/ops-weekly.yml`
New job `free-limits` (matrix or two steps: staging always; prod only when `vars.PROD_PROJECT_REF` is set — skip with a notice otherwise).
- Connect the same way `ci.yml` deploy does (`supabase/setup-cli`, `supabase link`, pooler URL, `PGPASSWORD` from `secrets.STAGING_DB_PASSWORD` / `secrets.PROD_DB_PASSWORD`). Keep diagnostics quiet like `db-backup.sh`.
- Query `pg_database_size(current_database())` and `coalesce(sum((metadata->>'size')::bigint),0) from storage.objects`.
- Thresholds from the spec: fail above 70 % of 500 MB DB / 1 GB storage. Put the limits and the 70 % in `env:` at the top of the job (no magic numbers in the script body). Print the numbers and percentages every run.
- On failure, message Telegram (`secrets.TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`, skip if unset) with which project and metric, plus the run URL — same pattern as the last step in `backup-prod.yml`.
- Also add the same Telegram failure step to the existing `token-expiry` job.
- Remove the "P2 adds ..." comment line. Document the upgrade trigger (any metric > 80 % or cohort > 300 → Pro; egress is not queryable, watch Supabase usage emails) in one short paragraph in `docs/setup/prod.md` (new §8 "Free-tier limits").

## Out of scope
`ci.yml`, `backup-prod.yml`, app code, migrations.

## Gates
PowerShell script runs with `-SelfTest` locally (paste output). Workflow YAML valid (`actionlint` if available, else `npx --yes @action-validator/cli` or careful review). `bash scripts/tests/secret-grep.test.sh` still passes. Do not commit.
