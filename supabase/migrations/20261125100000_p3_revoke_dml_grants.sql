-- P3.4 — authenticated/anon become read-only on public tables (docs/06 §4, docs/16 §2).
-- Every client write already goes through a security definer RPC or an Edge Function (service_role),
-- so the blanket DML grant from f2_rls_policies only widened the blast radius of a bad policy.
-- select grants stay (RLS gates reads); write RLS policies stay as defense in depth.

-- 1. Table-level writes (also clears column-level grants derived from them).
revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public from authenticated, anon;

-- 2. Explicit column-level writes granted in f2_rls_policies (profiles, notifications).
revoke update (full_name, phone, country, school, grade, timezone) on public.profiles from authenticated, anon;
revoke update (read_at) on public.notifications from authenticated, anon;

-- 3. Sequences: only needed by inserts, and inserts now run inside definer functions.
revoke usage, update on all sequences in schema public from authenticated, anon;

-- 4. New tables and sequences created by postgres stay write-less for the API roles.
alter default privileges for role postgres in schema public
  revoke insert, update, delete, truncate, references, trigger on tables from authenticated, anon;
alter default privileges for role postgres in schema public
  revoke usage, update on sequences from authenticated, anon;
