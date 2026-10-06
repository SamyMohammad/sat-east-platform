-- TEMPLATE (docs/16 §2) — copy into a migration, rename example_rpc and its arguments,
-- delete this header, walk supabase/templates/README.md checklist.
-- Needs: public.has_access(uuid), public.is_teacher() (docs/15 §1 row 3), public.settings (row 2b).
-- Errors: raise the 07 §9 code as the message; the client maps PostgrestException.message.

create or replace function public.example_rpc(p_course_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_pass_mark numeric;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_course_id is null then
    raise exception 'invalid_input';
  end if;

  if not public.has_access(p_course_id) then
    raise exception 'not_enrolled';
  end if;
  -- Teacher-only RPC instead: if not public.is_teacher() then raise exception 'forbidden'; end if;

  -- Tunables come from settings, never literals (CLAUDE.md rule 5).
  select (s.value)::numeric into v_pass_mark
  from public.settings s
  where s.key = 'pass_mark';

  -- Logic: fully-qualified names only (public.x, private.x); never trust client scores or timers.

  return jsonb_build_object('ok', true, 'pass_mark', v_pass_mark);
end;
$$;

revoke execute on function public.example_rpc(uuid) from public, anon;
grant execute on function public.example_rpc(uuid) to authenticated;
