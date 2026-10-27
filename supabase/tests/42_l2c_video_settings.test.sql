-- LRN-02 / SEC-01. From supabase/templates/test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select tests.create_supabase_user('video_settings_student');
select tests.authenticate_as('video_settings_student');
select is((select value from public.settings where key = 'video_progress_interval_s'),
          '15'::jsonb, 'LRN-02: student reads video progress interval');
select is((select value from public.settings where key = 'video_watermark_move_s'),
          '7'::jsonb, 'LRN-02: student reads watermark period');

select tests.clear_authentication();
reset role;
set local role anon;
select throws_ok($sql$ select value from public.settings where key = 'video_progress_interval_s' $sql$,
                 '42501', null, 'SEC-01: anon cannot read progress interval');
select throws_ok($sql$ select value from public.settings where key = 'video_watermark_move_s' $sql$,
                 '42501', null, 'SEC-01: anon cannot read watermark period');
reset role;

select * from finish();
rollback;
