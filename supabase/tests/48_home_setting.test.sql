-- LRN-07: from supabase/templates/test.sql. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

select is(
  (select value from public.settings where key = 'access_expiry_warn_days'),
  '14'::jsonb,
  'LRN-07: access_expiry_warn_days seeded as 14'
);

select tests.create_supabase_user('home_student');
select tests.authenticate_as('home_student');
select is(
  (select value from public.settings where key = 'access_expiry_warn_days'),
  '14'::jsonb,
  'LRN-07: authenticated can read access_expiry_warn_days'
);
select tests.clear_authentication();
reset role;

select * from finish();
rollback;
