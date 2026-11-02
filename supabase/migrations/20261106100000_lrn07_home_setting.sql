-- LRN-07: from supabase/templates/setting.sql; new tunable (CLAUDE.md rule 5).
-- Preserve any value already configured by the teacher.
insert into public.settings (key, value)
values ('access_expiry_warn_days', '14'::jsonb)
on conflict (key) do nothing;
