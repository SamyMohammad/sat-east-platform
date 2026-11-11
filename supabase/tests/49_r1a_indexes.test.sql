-- R1a / NFR-01, NFR-02: from supabase/templates/test.sql. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

-- Every FK has a non-partial index whose first column is the FK's first column.
select is_empty(
  $$
  select c.conrelid::regclass::text || '.' || a.attname as violator
  from pg_catalog.pg_constraint c
  join pg_catalog.pg_class t on t.oid = c.conrelid
  join pg_catalog.pg_namespace n on n.oid = t.relnamespace
  join pg_catalog.pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
  where c.contype = 'f'
    and n.nspname in ('public', 'private')
    and not exists (
      select 1 from pg_catalog.pg_index i
      where i.indrelid = c.conrelid
        and i.indpred is null
        and i.indkey[0] = c.conkey[1]
    )
  order by 1
  $$,
  'R1a: every foreign key column has a leading non-partial index'
);

select has_index(
  'public', 'attempts', 'attempts_quiz_in_progress_idx',
  'R1a: expire-attempts partial index exists'
);

select is(
  (select pg_catalog.pg_get_expr(i.indpred, i.indrelid)
   from pg_catalog.pg_index i
   where i.indexrelid = 'public.attempts_quiz_in_progress_idx'::regclass) is not null,
  true,
  'R1a: attempts_quiz_in_progress_idx is partial'
);

select is(
  (select value from public.settings where key = 'cron_history_keep_days'),
  '7'::jsonb,
  'R1a: cron_history_keep_days seeded as 7'
);

-- Purge: rows older than the keep window go, recent rows stay.
insert into cron.job_run_details (jobid, job_pid, database, username, command, status, return_message, start_time, end_time)
values
  (0, 0, 'postgres', 'postgres', 'r1a-purge-old', 'succeeded', 'ok',
   pg_catalog.now() - interval '8 days', pg_catalog.now() - interval '8 days'),
  (0, 0, 'postgres', 'postgres', 'r1a-purge-recent', 'succeeded', 'ok',
   pg_catalog.now() - interval '1 day', pg_catalog.now() - interval '1 day');

select private.nightly_cleanup();

select is(
  (select pg_catalog.array_agg(d.command order by d.command)
   from cron.job_run_details d where d.command like 'r1a-purge-%'),
  array['r1a-purge-recent'],
  'R1a: nightly_cleanup deletes old cron history and keeps recent rows'
);

select is(
  has_function_privilege('authenticated', 'private.nightly_cleanup()', 'execute'),
  false,
  'R1a: authenticated cannot execute private.nightly_cleanup()'
);

select * from finish();
rollback;
