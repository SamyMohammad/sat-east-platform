-- PAY-01 / PAY-04 — public catalogue + course page (docs/07 §1.1, §7).
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

select tests.create_supabase_user('student_eg');
update public.profiles set country = 'EG' where id = tests.get_supabase_uid('student_eg');

insert into public.courses (id, code, title, slug, description, is_published, sort) values
  ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', 'Digital SAT', true, 1),
  ('00000000-0000-0000-0000-0000000000c2', 'EST', 'EST Math', 'est', 'Hidden', false, 2);
insert into public.units (id, course_id, title, sort) values
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000c1', 'Unit B', 2),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'Unit A', 1),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000c1', 'Empty unit', 3);
insert into public.topics (id, course_id, unit_id, title, slug, sort, is_published, is_free_preview) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Linear', 'linear', 2, true, false),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Intro', 'intro', 1, true, true),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a2', 'Quadratics', 'quad', 1, true, false),
  ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a3', 'Draft', 'draft', 1, false, false);
insert into public.subtopics (topic_id, title) values
  ('00000000-0000-0000-0000-0000000000d1', 'Slope'), ('00000000-0000-0000-0000-0000000000d1', 'Intercepts');
insert into public.prices (course_id, currency, amount_minor, kind, active) values
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 150000, 'full', true),
  ('00000000-0000-0000-0000-0000000000c1', 'USD', 4900, 'full', true),
  ('00000000-0000-0000-0000-0000000000c1', 'EGP', 90000, 'renewal', true),
  ('00000000-0000-0000-0000-0000000000c2', 'USD', 3900, 'full', true);

-- Anonymous visitor: the catalogue is public (PAY-01).
set local role anon;
select is(jsonb_array_length(public.get_catalogue()), 1, 'PAY-01: catalogue lists published courses only');
select is(public.get_catalogue('EG') -> 0 -> 'price', '{"currency":"EGP","amount_minor":150000}'::jsonb,
          'PAY-04: Egypt sees the EGP full price (not renewal)');
select is(public.get_catalogue('AE') -> 0 -> 'price' ->> 'currency', 'USD', 'PAY-04: other countries see USD');
select is(public.get_catalogue() -> 0 -> 'price' ->> 'currency', 'USD', 'PAY-04: no hint → default currency');
select is(public.get_catalogue('eg') -> 0 -> 'price' ->> 'currency', 'EGP', 'PAY-04: country hint is case-insensitive');
select is((public.get_catalogue() -> 0 ->> 'topic_count')::int, 3, 'PAY-01: topic count counts published topics');
select is(public.get_catalogue() -> 0 ->> 'free_topic_slug', 'intro', 'PAY-01: free topic is exposed');

select is((select array_agg(u ->> 'title') from jsonb_array_elements(public.get_course_page('sat') -> 'units') u),
          array['Unit A', 'Unit B'], 'PAY-01: units sorted; a unit without published topics is hidden');
select is((select array_agg(t ->> 'slug') from jsonb_array_elements(public.get_course_page('sat') -> 'units' -> 0 -> 'topics') t),
          array['intro', 'linear'], 'PAY-01: topics sorted inside a unit');
select is(public.get_course_page('sat') -> 'units' -> 0 -> 'topics' -> 0 -> 'is_free_preview', 'true'::jsonb,
          'PAY-01: free preview flagged on the course page');
select is((public.get_course_page('sat') -> 'units' -> 0 -> 'topics' -> 1 ->> 'subtopic_count')::int, 2,
          'PAY-01: subtopic count per topic');
select is(public.get_course_page('sat', 'EG') -> 'price' ->> 'amount_minor', '150000', 'PAY-04: course page price in EGP');
select throws_ok($$ select public.get_course_page('est') $$, 'P0001', 'invalid_input',
                 'PAY-01: unpublished course page → invalid_input');
select throws_ok($$ select public.get_course_page('nope') $$, 'P0001', 'invalid_input',
                 'PAY-01: unknown slug → invalid_input');
reset role;

-- Signed-in student: profile country wins over the hint.
select tests.authenticate_as('student_eg');
select is(public.get_catalogue('US') -> 0 -> 'price' ->> 'currency', 'EGP',
          'PAY-04: profile country overrides the client hint');
select tests.clear_authentication();
reset role;

-- Missing price in the chosen currency → default; no price at all → null.
update public.settings set value = '{"EG": "EGP", "SA": "SAR", "default": "USD"}' where key = 'currency_by_country';
select is(public.get_catalogue('SA') -> 0 -> 'price' ->> 'currency', 'USD',
          'PAY-04: no SAR price yet → falls back to the default currency (setting is read)');
update public.prices set active = false where course_id = '00000000-0000-0000-0000-0000000000c1';
select is(public.get_catalogue('EG') -> 0 -> 'price', 'null'::jsonb, 'PAY-04: no active price → null');

-- Internal helpers are not callable from the API.
set local role anon;
select throws_ok($$ select private.currency_for('EG') $$, '42501', null, 'PAY-04: private helper not reachable by anon');
reset role;

select * from finish();
rollback;
