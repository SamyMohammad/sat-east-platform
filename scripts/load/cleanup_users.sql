-- R1c load test: remove every load student from STAGING. NEVER RUN AGAINST PROD.
-- Usage: psql "$url" -v ON_ERROR_STOP=1 -f scripts/load/cleanup_users.sql
-- Safe with zero load users (both deletes match nothing).
-- Deleting auth.users cascades to profiles, enrollments, attempts, progress and exposure.
-- private.rate_limits keys embed the user id (e.g. 'check_practice_answer:<uid>') and have no FK.
set client_min_messages = warning;

delete from private.rate_limits
where key like '%:00000000-0000-4000-8a0d-%';

delete from auth.users
where email like 'load-%@load.test';
