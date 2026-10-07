-- F-2 — docs/06 §6: settings defaults (Q-11, Q-14, docs/07); teacher changes survive a re-seed.
begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

select set_has('select key, value from public.settings', $$values
  ('pass_mark', '75'::jsonb), ('homework_size', '20'::jsonb), ('practice_min', '10'::jsonb),
  ('cooldown_h', '12'::jsonb), ('video_done_pct', '80'::jsonb), ('save_grace_s', '30'::jsonb),
  ('ai_daily_cap', '20'::jsonb), ('device_limit', '2'::jsonb), ('device_changes_30d', '2'::jsonb)$$,
  'settings seeded with docs/06 §6 defaults');

update public.settings set value = '80' where key = 'pass_mark';
insert into public.settings (key, value) values ('pass_mark', '75') on conflict (key) do nothing;
select is((select value from public.settings where key = 'pass_mark'), '80'::jsonb,
          're-seeding never overwrites a teacher-changed value');

select * from finish();
rollback;
