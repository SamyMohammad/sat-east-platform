-- F-2 / NFR-08 — docs/06 §§2–3: the starting schema exists exactly as specified.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select enums_are('public', array[
  'user_role','course_code','question_type','difficulty','question_status','question_pool',
  'attempt_kind','attempt_status','step_kind','enrollment_status','order_status','error_type'
], 'public enums match docs/06 §2');

select tables_are('public', array[
  'profiles','devices','device_changes',
  'courses','prices','coupons','orders','activation_codes','enrollments',
  'units','topics','subtopics','topic_assets','video_chapters','skills','subtopic_skills',
  'questions','question_courses','question_choices','question_skills','question_reports',
  'topic_progress','video_progress','attempts','attempt_questions','attempt_answers',
  'question_exposure','skill_mastery','mistake_notebook',
  'mock_templates','mock_forms','mock_results','official_scores',
  'ai_threads','ai_messages','escalations','live_sessions','announcements','notifications',
  'push_tokens','settings','audit_log'
], 'public tables match docs/06 §3');

select tables_are('private', array['question_keys','video_keys','rate_limits'],
  'secret tables live only in private');

select * from finish();
rollback;
