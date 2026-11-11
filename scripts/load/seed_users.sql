-- R1c load test: create :n load students on STAGING. NEVER RUN AGAINST PROD.
-- Usage: psql "$url" -v ON_ERROR_STOP=1 -v n=300 -f scripts/load/seed_users.sql
-- Ids 00000000-0000-4000-8a0d-<12-digit n> must match scripts/load/mint_tokens.mjs.
-- Idempotent: re-running leaves existing users alone and tops up missing ones.
-- Mirrors supabase/seeds/demo/ci_fixture.sql. The on_auth_user_created trigger creates the
-- profile (role student); the demo trigger demo_enroll_new_student enrols it. The explicit
-- enrolment insert below covers users whose profile pre-dates that trigger.
set client_min_messages = warning;

insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
select ('00000000-0000-4000-8a0d-' || lpad(g::text, 12, '0'))::uuid,
       'load-' || g || '@load.test',
       '{}'::jsonb, '{}'::jsonb, now(), now()
from generate_series(1, :n) as g
on conflict (id) do nothing;

insert into public.enrollments (user_id, course_id, status, expires_at)
select p.id, '00000000-0000-4000-8de0-000000000001', 'active', now() + interval '1 year'
from public.profiles p
join auth.users u on u.id = p.id
where u.email like 'load-%@load.test' and p.role = 'student'
on conflict (user_id, course_id) do nothing;

-- Verify (counts only, nothing secret): every load user needs a profile and an enrolment.
select count(*) >= :n and count(p.id) = count(*) and count(e.user_id) = count(*) as ok,
       count(*) as load_users, count(p.id) as profiles, count(e.user_id) as enrollments
from auth.users u
left join public.profiles p on p.id = u.id
left join public.enrollments e
  on e.user_id = u.id and e.course_id = '00000000-0000-4000-8de0-000000000001'
where u.email like 'load-%@load.test'
\gset
\echo load users :load_users, profiles :profiles, enrollments :enrollments
\if :ok
\else
  \echo 'load user seed incomplete (is the demo seed applied?)'
  select 1 / 0;
\endif
