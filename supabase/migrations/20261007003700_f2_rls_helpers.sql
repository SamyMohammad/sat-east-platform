-- F-2 row 3: RLS policy helpers (docs/06 §4, docs/16 §1 exception: they live in public because
-- policies run as the caller). Each reads only the caller's own data.

create function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'teacher'
  );
$$;

create function public.has_access(p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.enrollments
    where user_id = (select auth.uid())
      and course_id = p_course_id
      and status = 'active'
      and now() < expires_at
  );
$$;

create function public.has_access_topic(p_topic_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.topics t
    where t.id = p_topic_id
      and t.is_published
      and (t.is_free_preview or public.has_access(t.course_id))
  );
$$;

revoke execute on function public.is_teacher() from public, anon;
revoke execute on function public.has_access(uuid) from public, anon;
revoke execute on function public.has_access_topic(uuid) from public, anon;
grant execute on function public.is_teacher() to authenticated;
grant execute on function public.has_access(uuid) to authenticated;
grant execute on function public.has_access_topic(uuid) to authenticated;
