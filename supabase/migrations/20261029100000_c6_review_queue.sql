-- C-6 / QB-04 / QB-08 / T-08. From supabase/templates/rpc.sql + setting.sql.
-- Legacy direct inserts allowed duplicates; preserve every open status until reviewed.
do $$
begin
  if exists (
    select 1 from public.question_reports r where r.status = 'open'
    group by r.question_id,r.user_id having count(*) > 1
  ) then
    raise exception 'Cannot add report uniqueness while duplicate open reports exist'
      using errcode = '23505',
        hint = 'Resolve legacy duplicate open reports before rerunning this migration.';
  end if;
end;
$$;

alter table public.question_reports
  add column note text,
  add column resolved_at timestamptz,
  add column resolved_by uuid references public.profiles(id) on delete set null,
  add column teacher_note text;

update public.question_reports
set status = case when status = 'open' then 'open' else 'resolved_dismissed' end,
    reason = case when reason in ('answer_key','typo','math_display','other') then reason else 'other' end;
alter table public.question_reports
  add constraint question_reports_status_check check (status in ('open','resolved_fixed','resolved_dismissed')),
  add constraint question_reports_reason_check check (reason in ('answer_key','typo','math_display','other')),
  add constraint question_reports_note_length_check check (pg_catalog.char_length(note) <= 500),
  add constraint question_reports_teacher_note_length_check check (pg_catalog.char_length(teacher_note) <= 500);
create unique index question_reports_one_open_per_student
  on public.question_reports(question_id,user_id) where status = 'open';
drop policy "question_reports: student inserts own" on public.question_reports;

insert into public.settings(key,value) values ('rate_report_per_min','5'::jsonb)
on conflict(key) do nothing;

create function public.report_question(p_question_id uuid, p_reason text, p_note text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_topic uuid;
  v_note text;
  v_id uuid;
  v_key text;
  v_limit int;
  v_count int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_reason is null or p_reason not in ('answer_key','typo','math_display','other') then
    raise exception 'invalid_input';
  end if;
  v_note := nullif(pg_catalog.btrim(p_note), '');
  if pg_catalog.char_length(v_note) > 500 then raise exception 'invalid_input'; end if;
  -- Shared question lock serializes reporting against resolve-all and status changes.
  select q.topic_id into v_topic from public.questions q
  where q.id = p_question_id and q.status = 'published' for share;
  if not found or not public.has_access_topic(v_topic) then raise exception 'invalid_input'; end if;

  v_limit := private.setting_int('rate_report_per_min');
  if v_limit is null or v_limit < 0 then raise exception 'invalid_input'; end if;
  v_key := 'report_question:' || v_uid;
  -- NULL disables the helper's raise; count first, then return a committed quota error.
  -- Catching its rate_limited exception would roll back the counter write.
  perform private.hit_rate_limit(v_key, null, 60);
  select r.count into v_count from private.rate_limits r
  where r.key = v_key and r.window_start = pg_catalog.to_timestamp(
    pg_catalog.floor(extract(epoch from pg_catalog.now()) / 60) * 60);
  if v_count > v_limit then
    return pg_catalog.jsonb_build_object('ok',false,'error','rate_limited');
  end if;

  select r.id into v_id from public.question_reports r
  where r.question_id = p_question_id and r.user_id = v_uid and r.status = 'open';
  if found then
    return pg_catalog.jsonb_build_object('ok',true,'report_id',v_id,'existing',true);
  end if;
  loop
    begin
      insert into public.question_reports(question_id,user_id,reason,note)
      values(p_question_id,v_uid,p_reason,v_note) returning id into v_id;
      return pg_catalog.jsonb_build_object('ok',true,'report_id',v_id,'existing',false);
    exception when unique_violation then
      -- Only the insert rolls back; the quota increment remains outside this block.
      select r.id into v_id from public.question_reports r
      where r.question_id = p_question_id and r.user_id = v_uid and r.status = 'open';
      if found then
        return pg_catalog.jsonb_build_object('ok',true,'report_id',v_id,'existing',true);
      end if;
    end;
  end loop;
end;
$$;
revoke execute on function public.report_question(uuid,text,text) from public,anon;
grant execute on function public.report_question(uuid,text,text) to authenticated;

create function public.teacher_list_review_queue(p_section text, p_page int)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_size int;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if p_section is null or p_section not in ('reported','needs_review') or p_page is null or p_page < 1 then
    raise exception 'invalid_input';
  end if;
  select s.value::int into v_size from public.settings s where s.key = 'bank_page_size';
  if v_size is null or v_size < 1 then raise exception 'invalid_input'; end if;
  with open_reports as materialized (
    select r.id,r.question_id,r.reason,r.note,r.created_at
    from public.question_reports r where r.status = 'open'
  ), grouped as (
    select r.question_id,count(*) as open_count,min(r.created_at) as oldest_report_at
    from open_reports r group by r.question_id
  ), reason_counts as (
    select r.question_id,r.reason,count(*) as n from open_reports r group by r.question_id,r.reason
  ), reasons as (
    select r.question_id,pg_catalog.jsonb_object_agg(r.reason,r.n) as reasons
    from reason_counts r group by r.question_id
  ), latest as (
    select distinct on (r.question_id) r.question_id,r.note
    from open_reports r where r.note is not null
    order by r.question_id,r.created_at desc,r.id desc
  ), matching as materialized (
    select q.id as question_id,q.external_ref,
      pg_catalog.split_part(q.stem_md,pg_catalog.chr(10),1) as stem_preview,q.status,
      coalesce(g.open_count,0) as open_count,g.oldest_report_at,
      coalesce(r.reasons,'{}'::jsonb) as reasons,l.note as latest_note
    from public.questions q left join grouped g on g.question_id = q.id
    left join reasons r on r.question_id = q.id left join latest l on l.question_id = q.id
    where (p_section = 'reported' and g.open_count > 0)
      or (p_section = 'needs_review' and q.status = 'needs_review')
  ), page_rows as (
    select * from matching order by open_count desc,oldest_report_at asc nulls last,question_id
    limit v_size offset ((p_page::bigint - 1) * v_size)
  )
  select pg_catalog.jsonb_build_object('total',(select count(*) from matching),
    'page',p_page,'page_size',v_size,'rows',coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r)
      order by r.open_count desc,r.oldest_report_at asc nulls last,r.question_id) from page_rows r),'[]'::jsonb))
  into v_result;
  return v_result;
end;
$$;
revoke execute on function public.teacher_list_review_queue(text,int) from public,anon;
grant execute on function public.teacher_list_review_queue(text,int) to authenticated;

create function public.teacher_list_question_reports(p_question_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  if p_question_id is null or not exists(select 1 from public.questions q where q.id = p_question_id) then
    raise exception 'invalid_input';
  end if;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'report_id',r.id,'reason',r.reason,'note',r.note,'created_at',r.created_at,'full_name',p.full_name)
    order by r.created_at,r.id),'[]'::jsonb) into v_result
  from public.question_reports r join public.profiles p on p.id = r.user_id
  where r.question_id = p_question_id and r.status = 'open';
  return v_result;
end;
$$;
revoke execute on function public.teacher_list_question_reports(uuid) from public,anon;
grant execute on function public.teacher_list_question_reports(uuid) to authenticated;

create function public.teacher_resolve_reports(p_question_id uuid, p_outcome text, p_note text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_note text;
  v_closed int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  v_note := nullif(pg_catalog.btrim(p_note), '');
  if p_outcome is null or p_outcome not in ('fixed','dismissed') or pg_catalog.char_length(v_note) > 500 then
    raise exception 'invalid_input';
  end if;
  perform 1 from public.questions q where q.id = p_question_id for update;
  if not found then raise exception 'invalid_input'; end if;
  update public.question_reports set status = 'resolved_' || p_outcome,
    resolved_at = pg_catalog.now(),resolved_by = v_uid,teacher_note = v_note
  where question_id = p_question_id and status = 'open';
  get diagnostics v_closed = row_count;
  insert into public.audit_log(actor,action,entity,entity_id,diff)
  values(v_uid,'question_reports.resolve','question',p_question_id,
    pg_catalog.jsonb_build_object('outcome',p_outcome,'closed',v_closed));
  return pg_catalog.jsonb_build_object('closed',v_closed);
end;
$$;
revoke execute on function public.teacher_resolve_reports(uuid,text,text) from public,anon;
grant execute on function public.teacher_resolve_reports(uuid,text,text) to authenticated;

create function public.teacher_review_counts()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_teacher() then raise exception 'forbidden'; end if;
  return pg_catalog.jsonb_build_object(
    'reported',(select count(distinct r.question_id) from public.question_reports r where r.status = 'open'),
    'needs_review',(select count(*) from public.questions q where q.status = 'needs_review'));
end;
$$;
revoke execute on function public.teacher_review_counts() from public,anon;
grant execute on function public.teacher_review_counts() to authenticated;
