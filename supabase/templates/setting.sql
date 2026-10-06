-- TEMPLATE (docs/16 §2) — new tunable (CLAUDE.md rule 5). Copy into a migration.
-- Needs: public.settings(key text primary key, value jsonb, updated_at) (docs/15 §1 row 2b).
-- value is jsonb: numbers '75', strings '"EGP"', objects '{"m1": 22}'.

insert into public.settings (key, value)
values ('example_key', '75'::jsonb)
on conflict (key) do nothing;  -- never overwrite a value a teacher has already changed
