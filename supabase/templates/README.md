# SQL / Edge Function templates

Every new SQL file starts as a copy of one of these (CLAUDE.md rule 10, docs/16 §2).
Nothing in this folder is applied or deployed — copy, rename, then delete the template header.

| Template | Use for |
|----------|---------|
| `table.sql` | New table: RLS, explicit grants, select-own + teacher-all policies, index |
| `rpc.sql` | New RPC: `security definer`, `search_path = ''`, `auth.uid()` check, 07 §9 error codes, explicit grant |
| `setting.sql` | New tunable in `settings` (`on conflict do nothing`) |
| `test.sql` | pgTAP: student A vs B, teacher, anon, RPC permission |
| `edge-function.ts` | Edge Function route: JWT → RPC as the user → `{ error: { code, message } }` |

Workflow: `supabase migration new <name>` → paste template → rename → write the test from
`test.sql` → `scripts/db-reset.ps1` → `scripts/db-test.ps1` → walk the checklist below.

## Review checklist (every SQL change)

1. New table in `public` or `private`? Anything holding answers or secrets → `private`.
2. `enable row level security` and at least one policy?
3. Policies are `to authenticated` and compare with `(select auth.uid())`? (Without it every student sees everything.) UPDATE policies have both `using` and `with check`. No `auth.role()`, no `user_metadata`.
4. `security definer` function? Then `set search_path = ''` and fully-qualified names (`public.x`).
5. Function checks `auth.uid()` on its first line?
6. `grant execute … to authenticated` only (not `anon`), after `revoke … from public, anon`?
7. Table grants match the policies (nothing is granted by default — hardening Layer 3)? No `anon` grant unless the data is public.
8. Any fixed number (pass mark, cooldown …)? It must be read from `settings`.
9. New pgTAP test, and `scripts/db-test.ps1` passes?

Also before a PR: `supabase db lint` and `supabase db advisors` show no new findings.
