-- LRN-02. From supabase/templates/setting.sql.
insert into public.settings (key, value)
values ('video_watermark_move_s', '7'::jsonb)
on conflict (key) do nothing;  -- never overwrite a value a teacher has already changed
