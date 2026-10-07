-- F-2 / NFR-07 / NFR-08 — docs/06 §4 learning rows: attempts, answers (rule 1), orders, AI, self-reported rows.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

select tests.create_supabase_user('student_a');
select tests.create_supabase_user('student_b');
select tests.create_supabase_user('teacher');
update public.profiles set role = 'teacher' where id = tests.get_supabase_uid('teacher');

insert into public.courses (id, code, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000c1', 'SAT', 'SAT Math', 'sat', true);
insert into public.topics (id, course_id, title, slug, is_published)
  values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', 'T', 't', true);
insert into public.subtopics (id, topic_id, title)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', 'S');
insert into public.questions (id, topic_id, subtopic_id, type, difficulty, stem_md, pool) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'x', 'quiz'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000e1', 'mcq', 'E', 'y', 'quiz');
insert into public.attempts (id, user_id, kind, course_id, status) values
  ('00000000-0000-0000-0000-0000000000a1', tests.get_supabase_uid('student_a'), 'quiz', '00000000-0000-0000-0000-0000000000c1', 'in_progress'),
  ('00000000-0000-0000-0000-0000000000a2', tests.get_supabase_uid('student_a'), 'quiz', '00000000-0000-0000-0000-0000000000c1', 'submitted'),
  ('00000000-0000-0000-0000-0000000000a3', tests.get_supabase_uid('student_b'), 'quiz', '00000000-0000-0000-0000-0000000000c1', 'submitted');
insert into public.attempt_questions (attempt_id, question_id, position) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', 1),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000f2', 1),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000f1', 1);
insert into public.attempt_answers (attempt_id, question_id, answer, is_correct) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', '{"choice":"A"}', true),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000f2', '{"choice":"B"}', false),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000f1', '{"choice":"C"}', false);
insert into public.prices (id, course_id, currency, amount_minor, kind)
  values ('00000000-0000-0000-0000-0000000000a7', '00000000-0000-0000-0000-0000000000c1', 'EGP', 100000, 'full');
insert into public.orders (user_id, course_id, price_id, amount_minor, currency, gateway, raw_payload) values
  (tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a7', 100000, 'EGP', 'paymob', '{"card":"secret"}'),
  (tests.get_supabase_uid('student_b'), '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a7', 100000, 'EGP', 'paymob', '{}');
insert into public.ai_threads (id, user_id, question_id) values
  ('00000000-0000-0000-0000-0000000000b1', tests.get_supabase_uid('student_a'), '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000b2', tests.get_supabase_uid('student_b'), '00000000-0000-0000-0000-0000000000f1');
insert into public.ai_messages (thread_id, role, content) values
  ('00000000-0000-0000-0000-0000000000b1', 'user', 'help'),
  ('00000000-0000-0000-0000-0000000000b2', 'user', 'help');

select tests.authenticate_as('student_a');
select is((select count(*)::int from public.attempts), 2, 'NFR-08: student sees only own attempts');
select is((select count(*)::int from public.attempt_answers
           where attempt_id = '00000000-0000-0000-0000-0000000000a1'), 0,
          'NFR-07: answers of an in-progress attempt are hidden (rule 1)');
select is((select count(*)::int from public.attempt_answers), 1,
          'NFR-08: student sees answers of own submitted attempts only');
select throws_ok($$ select raw_payload from public.orders $$, '42501', null,
                 'NFR-08: student cannot read raw gateway payloads');
select is((select count(id)::int from public.orders), 1, 'NFR-08: student sees own orders');
select is((select count(*)::int from public.ai_messages), 1, 'NFR-08: student sees only own AI messages');
select throws_ok($$ insert into public.ai_messages (thread_id, role, content)
                    values ('00000000-0000-0000-0000-0000000000b1', 'assistant', 'fake') $$, '42501', null,
                 'NFR-08: student cannot write AI messages (ai-tutor EF only)');
select throws_ok($$ insert into public.attempts (user_id, kind, course_id)
                    values (auth.uid(), 'quiz', '00000000-0000-0000-0000-0000000000c1') $$, '42501', null,
                 'NFR-08: student cannot create attempts directly (RPC only)');
select lives_ok($$ insert into public.official_scores (user_id, course_id, score, taken_on)
                   values (auth.uid(), '00000000-0000-0000-0000-0000000000c1', 650, current_date) $$,
                'NFR-08: student records own official score');
select throws_ok(format($$ insert into public.official_scores (user_id, course_id, score, taken_on)
                           values (%L, '00000000-0000-0000-0000-0000000000c1', 800, current_date) $$,
                        tests.get_supabase_uid('student_b')), '42501', null,
                 'NFR-08: student cannot record a score for someone else');
select throws_ok($$ insert into public.enrollments (user_id, course_id, expires_at)
                    values (auth.uid(), '00000000-0000-0000-0000-0000000000c1', now() + interval '1 year') $$, '42501', null,
                 'NFR-08: student cannot enroll themselves');
select throws_ok($$ insert into public.devices (user_id, device_fingerprint) values (auth.uid(), 'fp-x') $$, '42501', null,
                 'NFR-08: student cannot register devices directly (register-device EF only)');
select throws_ok($$ insert into public.topic_progress (user_id, topic_id, quiz_passed_at)
                    values (auth.uid(), '00000000-0000-0000-0000-0000000000d1', now()) $$, '42501', null,
                 'NFR-08: student cannot write own progress (unlocks are server-side)');
select is_empty($$ update public.attempts set status = 'submitted'
                   where id = '00000000-0000-0000-0000-0000000000a1' returning id $$,
                'NFR-07: student cannot submit an attempt directly (would expose answers)');
select lives_ok($$ insert into public.question_reports (question_id, user_id, reason)
                   values ('00000000-0000-0000-0000-0000000000f1', auth.uid(), 'typo') $$,
                'NFR-08: student reports a question');

select tests.authenticate_as('teacher');
select is((select count(*)::int from public.attempt_answers), 3, 'NFR-08: teacher sees all answers');
select is((select count(id)::int from public.orders), 2, 'NFR-08: teacher sees all orders');
select throws_ok($$ insert into public.audit_log (action, entity) values ('x', 'y') $$, '42501', null,
                 'NFR-08: audit_log is read-only through the API');

select * from finish();
rollback;
