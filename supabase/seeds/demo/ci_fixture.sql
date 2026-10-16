-- CI-only fixture (not matched by the [0-9]*.sql seed glob). Creates a throwaway
-- student BEFORE the seed runs so the seed's "enrol existing students" insert is
-- exercised (check.sql check 8 would otherwise be vacuous). The CI step deletes it
-- after check.sql; the delete cascades to its profile and enrolment.
insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8de0-0000000000f1', 'fixture@demo-ci-fixture.test',
        '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;
