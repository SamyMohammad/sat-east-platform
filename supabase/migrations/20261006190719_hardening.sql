-- F-2 hardening (docs/16 §1, layers 1–3). First migration: runs before any table or function exists.
-- Layer 4 (CI gate: every public table has RLS + a policy) lands with the RLS baseline (docs/15 §1 row 3).

-- Layer 1 — private schema for secrets and internal helpers.
-- Never list it in supabase/config.toml [api] schemas, so PostgREST can never expose it.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
