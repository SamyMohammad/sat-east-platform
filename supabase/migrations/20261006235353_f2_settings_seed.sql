-- F-2 row 2b: settings defaults (docs/06 §6). Never overwrite a value the teacher changed.
insert into public.settings (key, value) values
  ('pass_mark',          '75'),
  ('homework_size',      '20'),
  ('practice_min',       '10'),
  ('cooldown_h',         '12'),
  ('video_done_pct',     '80'),
  ('save_grace_s',       '30'),
  ('ai_daily_cap',       '20'),
  ('device_limit',       '2'),
  ('device_changes_30d', '2')
on conflict (key) do nothing;
