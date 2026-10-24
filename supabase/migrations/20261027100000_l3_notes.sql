-- L-3 / SEC-02 / C-3. From templates/rpc.sql, table.sql and setting.sql.
insert into public.settings(key,value) values ('notes_max_mb','20'::jsonb)
on conflict(key) do nothing;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
select 'notes','notes',false,(s.value::bigint)*1024*1024,array['application/pdf']
from public.settings s where s.key='notes_max_mb'
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,
 allowed_mime_types=excluded.allowed_mime_types;

alter table public.topic_assets
 add column ready boolean not null default false,
 add column updated_at timestamptz not null default now();
alter table public.topic_assets enable row level security;
grant select(ready,updated_at) on public.topic_assets to authenticated;

-- The policy calls this stored function by OID; private schema USAGE stays revoked.
create function private.notes_object_readable(p_name text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare
 v_uid uuid := auth.uid();
 v_parts text[];
 v_topic uuid;
 v_asset uuid;
begin
 if v_uid is null then return false; end if;
 v_parts := pg_catalog.regexp_match(p_name,
  '^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})[.]pdf$');
 if v_parts is null then return false; end if;
 v_topic := v_parts[1]::uuid;
 v_asset := v_parts[2]::uuid;
 if public.is_teacher() then return true; end if;
 return exists (
  select 1 from public.topic_assets a
  join public.topics t on t.id=a.topic_id
  join public.courses c on c.id=t.course_id
  cross join lateral private.topic_states(v_uid,c.id) ts
  where a.id=v_asset and a.topic_id=v_topic and a.kind='notes' and a.ready
   and a.storage_path=p_name and c.is_published and t.is_published
   and public.has_access(c.id) and ts.topic_id=t.id and ts.status in ('open','completed'));
end;
$$;
revoke all on function private.notes_object_readable(text) from public,anon,authenticated,service_role;
grant execute on function private.notes_object_readable(text) to authenticated;

create policy "notes: read accessible object" on storage.objects
 for select to authenticated
 using (bucket_id='notes' and private.notes_object_readable(name));
create policy "notes: teacher inserts" on storage.objects
 for insert to authenticated
 with check (bucket_id='notes' and public.is_teacher());
create policy "notes: teacher updates" on storage.objects
 for update to authenticated
 using (bucket_id='notes' and public.is_teacher())
 with check (bucket_id='notes' and public.is_teacher());
create policy "notes: teacher deletes" on storage.objects
 for delete to authenticated
 using (bucket_id='notes' and public.is_teacher());

-- Preserve the non-notes policy, but do not expose pending/locked notes metadata.
drop policy "topic_assets: student with topic access" on public.topic_assets;
create policy "topic_assets: student with topic access" on public.topic_assets
 for select to authenticated using (public.has_access_topic(topic_id)
  and (kind<>'notes' or (ready and private.notes_object_readable(topic_id::text||'/'||id::text||'.pdf'))));

create function private.require_notes_opened(p_uid uuid,p_topic_id uuid)
returns void language plpgsql stable set search_path='' as $$
begin
 if exists(select 1 from public.topic_assets a where a.topic_id=p_topic_id and a.kind='notes' and a.ready)
  and not exists(select 1 from public.topic_progress p
   where p.user_id=p_uid and p.topic_id=p_topic_id and p.notes_opened_at is not null) then
  raise exception 'notes_needed';
 end if;
end;
$$;
revoke all on function private.require_notes_opened(uuid,uuid) from public,anon,authenticated,service_role;

create function public.mark_notes_opened(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_uid uuid := auth.uid();
 v_topic uuid;
 v_opened timestamptz;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select a.topic_id into v_topic from public.topic_assets a
 where a.id=p_asset_id and a.kind='notes' and a.ready for share;
 if not found then raise exception 'invalid_input'; end if;
 perform private.practice_access(v_uid,v_topic);
 insert into public.topic_progress as p(user_id,topic_id,notes_opened_at)
 values(v_uid,v_topic,now()) on conflict(user_id,topic_id)
 do update set notes_opened_at=coalesce(p.notes_opened_at,excluded.notes_opened_at)
 returning notes_opened_at into v_opened;
 return pg_catalog.jsonb_build_object('notes_opened_at',v_opened);
end;
$$;
revoke execute on function public.mark_notes_opened(uuid) from public,anon;
grant execute on function public.mark_notes_opened(uuid) to authenticated;

create function public.teacher_create_notes_asset(p_topic_id uuid,p_subtopic_id uuid,p_title text,p_page_count int)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_asset public.topic_assets%rowtype;
 v_id uuid := pg_catalog.gen_random_uuid();
 v_sort int;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_title is null or pg_catalog.length(pg_catalog.btrim(p_title)) not between 1 and 120
  or p_page_count is null or p_page_count<=0 then raise exception 'invalid_input'; end if;
 perform 1 from public.topics where id=p_topic_id for update;
 if not found then raise exception 'invalid_input'; end if;
 if p_subtopic_id is not null then
  perform 1 from public.subtopics where id=p_subtopic_id and topic_id=p_topic_id for share;
  if not found then raise exception 'invalid_input'; end if;
 end if;
 select coalesce(max(a.sort),0)+1 into v_sort from public.topic_assets a where a.topic_id=p_topic_id and a.kind='notes';
 insert into public.topic_assets(id,topic_id,subtopic_id,kind,title,sort,storage_path,page_count)
 values(v_id,p_topic_id,p_subtopic_id,'notes',pg_catalog.btrim(p_title),v_sort,p_topic_id::text||'/'||v_id::text||'.pdf',p_page_count)
 returning * into v_asset;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'notes.create','topic_asset',v_id,pg_catalog.jsonb_build_object('after',pg_catalog.to_jsonb(v_asset)));
 return pg_catalog.jsonb_build_object('asset_id',v_id,'path',v_asset.storage_path);
end;
$$;
revoke execute on function public.teacher_create_notes_asset(uuid,uuid,text,int) from public,anon;
grant execute on function public.teacher_create_notes_asset(uuid,uuid,text,int) to authenticated;

create function public.teacher_confirm_notes_asset(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before public.topic_assets%rowtype; v_after public.topic_assets%rowtype;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 select * into v_before from public.topic_assets where id=p_asset_id and kind='notes' for update;
 if not found then raise exception 'invalid_input'; end if;
 perform 1 from storage.objects where bucket_id='notes' and name=v_before.storage_path for key share;
 if not found then raise exception 'invalid_input'; end if;
 if not v_before.ready then
  update public.topic_assets set ready=true,updated_at=now() where id=p_asset_id returning * into v_after;
  insert into public.audit_log(actor,action,entity,entity_id,diff)
  values(auth.uid(),'notes.confirm','topic_asset',p_asset_id,
   pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(v_before),'after',pg_catalog.to_jsonb(v_after)));
 end if;
 return pg_catalog.jsonb_build_object('ok',true);
end;
$$;
revoke execute on function public.teacher_confirm_notes_asset(uuid) from public,anon;
grant execute on function public.teacher_confirm_notes_asset(uuid) to authenticated;

create function public.teacher_update_notes_asset(p_asset_id uuid,p_title text,p_subtopic_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before public.topic_assets%rowtype; v_after public.topic_assets%rowtype;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_title is null or pg_catalog.length(pg_catalog.btrim(p_title)) not between 1 and 120 then raise exception 'invalid_input'; end if;
 select * into v_before from public.topic_assets where id=p_asset_id and kind='notes' for update;
 if not found then raise exception 'invalid_input'; end if;
 if p_subtopic_id is not null then
  perform 1 from public.subtopics where id=p_subtopic_id and topic_id=v_before.topic_id for share;
  if not found then raise exception 'invalid_input'; end if;
 end if;
 update public.topic_assets set title=pg_catalog.btrim(p_title),subtopic_id=p_subtopic_id,updated_at=now()
 where id=p_asset_id returning * into v_after;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'notes.update','topic_asset',p_asset_id,
  pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(v_before),'after',pg_catalog.to_jsonb(v_after)));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$$;
revoke execute on function public.teacher_update_notes_asset(uuid,text,uuid) from public,anon;
grant execute on function public.teacher_update_notes_asset(uuid,text,uuid) to authenticated;

create function public.teacher_reorder_notes(p_topic_id uuid,p_ids uuid[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_current uuid[]; v_expected uuid[]; v_before jsonb;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_ids is null or pg_catalog.array_ndims(p_ids)>1 then raise exception 'invalid_input'; end if;
 perform 1 from public.topics where id=p_topic_id for update;
 if not found then raise exception 'invalid_input'; end if;
 perform 1 from public.topic_assets where topic_id=p_topic_id and kind='notes' order by id for update;
 select coalesce(pg_catalog.array_agg(id order by id),'{}'::uuid[]),
  coalesce(pg_catalog.jsonb_agg(id order by sort,id),'[]'::jsonb)
 into v_current,v_before from public.topic_assets where topic_id=p_topic_id and kind='notes';
 select coalesce(pg_catalog.array_agg(id order by id),'{}'::uuid[]) into v_expected from pg_catalog.unnest(p_ids) id;
 if v_current is distinct from v_expected then raise exception 'invalid_input'; end if;
 update public.topic_assets a set sort=i.position::int,updated_at=now()
 from pg_catalog.unnest(p_ids) with ordinality i(id,position) where a.id=i.id;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'notes.reorder','topic',p_topic_id,pg_catalog.jsonb_build_object('before',v_before,'after',p_ids));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$$;
revoke execute on function public.teacher_reorder_notes(uuid,uuid[]) from public,anon;
grant execute on function public.teacher_reorder_notes(uuid,uuid[]) to authenticated;

create function public.teacher_delete_notes_asset(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before public.topic_assets%rowtype;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 select * into v_before from public.topic_assets where id=p_asset_id and kind='notes' for update;
 if not found then raise exception 'invalid_input'; end if;
 delete from public.topic_assets where id=p_asset_id;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'notes.delete','topic_asset',p_asset_id,pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(v_before)));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$$;
revoke execute on function public.teacher_delete_notes_asset(uuid) from public,anon;
grant execute on function public.teacher_delete_notes_asset(uuid) to authenticated;

-- Latest definition copied from 20261017200100_prc03_quiz.sql; notes additions only.
create or replace function public.get_topic(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_quiz jsonb;
  v_topic record;
  v_label text;
  v_notes jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;
  perform private.expire_quiz(v_uid, p_topic_id);
  v_quiz := private.quiz_state(v_uid, p_topic_id);
  select ts.* into v_topic from public.topics t
  cross join lateral private.topic_states(v_uid, t.course_id) ts
  where t.id = p_topic_id and ts.topic_id = t.id;
  v_label := v_topic.topic_no::text;
  if v_topic.unit_id is not null then
    v_label := v_topic.unit_no || '.' || v_topic.topic_no;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('asset_id', a.id, 'title', a.title,
    'subtopic_title', s.title, 'page_count', a.page_count) order by a.sort, a.id), '[]'::jsonb)
  into v_notes from public.topic_assets a left join public.subtopics s on s.id = a.subtopic_id
  where a.topic_id = p_topic_id and a.kind = 'notes' and a.ready;
  return jsonb_build_object('id', p_topic_id, 'title', v_topic.title, 'slug', v_topic.slug,
    'sort_label', v_label, 'status', v_topic.status,
    'practice', jsonb_build_object('count', v_quiz -> 'practice_count', 'min', v_quiz -> 'practice_min'),
    'quiz', v_quiz,
    'notes', v_notes, 'notes_done', v_notes = '[]'::jsonb or exists (
      select 1 from public.topic_progress p where p.user_id = v_uid and p.topic_id = p_topic_id
        and p.notes_opened_at is not null));
end;
$$;
revoke execute on function public.get_topic(uuid) from public, anon;
grant execute on function public.get_topic(uuid) to authenticated;

-- Latest definition copied from 20261018100100_lane2a_rate_limit.sql; notes additions only.
create or replace function public.get_practice_questions(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_course_id uuid;
  v_size      int;
  v_attempt   uuid;
  v_n         int;
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('get_practice_questions:' || v_uid, private.setting_int('rate_start_per_min'), 60);

  if p_topic_id is null then
    raise exception 'invalid_input';
  end if;

  v_course_id := private.practice_access(v_uid, p_topic_id);
  perform private.require_notes_opened(v_uid, p_topic_id);
  v_size := private.setting_int('practice_min');

  insert into public.attempts (user_id, kind, course_id, topic_id, status)
  values (v_uid, 'practice', v_course_id, p_topic_id, 'in_progress')
  returning id into v_attempt;

  -- random() is evaluated once per row in the inner query; positions follow the same order.
  insert into public.attempt_questions (attempt_id, question_id, position)
  select v_attempt, d.id, row_number() over (order by d.unseen desc, d.r)
  from (
    select q.id, (x.question_id is null) as unseen, random() as r
    from public.questions q
    left join public.question_exposure x on x.question_id = q.id and x.user_id = v_uid
    where q.topic_id = p_topic_id and q.pool = 'practice' and q.status = 'published'
    order by unseen desc, r
    limit v_size
  ) d;
  get diagnostics v_n = row_count;

  if v_n = 0 then
    raise exception 'pool_exhausted';  -- rolls back the attempt row
  end if;

  insert into public.question_exposure (user_id, question_id)
  select v_uid, aq.question_id
  from public.attempt_questions aq
  where aq.attempt_id = v_attempt
  on conflict (user_id, question_id) do nothing;

  -- No key, explanation, hint or misconceptions here.
  select jsonb_agg(
           jsonb_build_object(
             'id', q.id,
             'type', q.type,
             'difficulty', q.difficulty,
             'stem_md', q.stem_md,
             'choices', coalesce((
               select jsonb_agg(jsonb_build_object('label', c.label, 'body_md', c.body_md) order by c.label)
               from public.question_choices c
               where c.question_id = q.id), '[]'::jsonb)
           ) order by aq.position)
  into v_questions
  from public.attempt_questions aq
  join public.questions q on q.id = aq.question_id
  where aq.attempt_id = v_attempt;

  return jsonb_build_object('attempt_id', v_attempt, 'rep_target', v_n, 'questions', v_questions);
end;
$$;
revoke execute on function public.get_practice_questions(uuid) from public, anon;
grant execute on function public.get_practice_questions(uuid) to authenticated;

-- Latest definition copied from 20261018200000_lrn04_review_set.sql; notes additions only.
create or replace function public.check_practice_answer(
  p_attempt_id  uuid,
  p_question_id uuid,
  p_answer      text,
  p_time_ms     int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_att     public.attempts%rowtype;
  v_q       public.questions%rowtype;
  v_key     private.question_keys%rowtype;
  v_row     public.attempt_answers%rowtype;
  v_ans     text;
  v_time    int;
  v_tries   jsonb;
  v_try     int;
  v_correct boolean;
  v_counts  boolean;
  v_replay  boolean := false;
  v_show    jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform private.hit_rate_limit('check_practice_answer:' || v_uid, private.setting_int('rate_answer_per_min'), 60);

  if p_attempt_id is null or p_question_id is null or p_answer is null then
    raise exception 'invalid_input';
  end if;

  -- Locks the attempt so a retried request waits and then replays.
  select a.* into v_att
  from public.attempts a
  where a.id = p_attempt_id
    and a.user_id = v_uid
    and a.kind in ('practice', 'review')
    and (a.status = 'in_progress' or (a.kind = 'review' and a.status = 'submitted'))
    and exists (select 1 from public.attempt_questions aq
                where aq.attempt_id = a.id and aq.question_id = p_question_id)
  for update;
  if not found then
    raise exception 'invalid_input';
  end if;

  perform private.practice_access(v_uid, v_att.topic_id);
  perform private.require_notes_opened(v_uid, v_att.topic_id);

  select q.* into v_q from public.questions q
  where q.id = p_question_id and q.pool = 'practice' and q.status = 'published' and q.topic_id = v_att.topic_id;
  if not found then
    raise exception 'invalid_input';
  end if;

  select k.* into v_key from private.question_keys k where k.question_id = p_question_id;
  if not found then
    raise exception 'invalid_key';
  end if;

  v_ans := btrim(p_answer);
  if v_q.type = 'mcq' then
    v_ans := upper(v_ans);
  end if;
  if v_ans = '' or length(v_ans) > 32 then
    raise exception 'invalid_input';
  end if;
  v_time := greatest(0, least(coalesce(p_time_ms, 0), 3600000));

  select aa.* into v_row
  from public.attempt_answers aa
  where aa.attempt_id = p_attempt_id and aa.question_id = p_question_id;

  if found then
    v_tries := coalesce(v_row.answer -> 'tries', '[]'::jsonb);
    if jsonb_array_length(v_tries) > 0 and v_tries ->> -1 = v_ans then
      -- Replay: rebuild the stored result, write nothing.
      v_replay := true;
      v_try := jsonb_array_length(v_tries);
      v_correct := coalesce(v_row.is_correct, false);
    elsif v_row.is_correct or jsonb_array_length(v_tries) <> 1 then
      raise exception 'invalid_input';
    else
      v_try := 2;
    end if;
  else
    v_tries := '[]'::jsonb;
    v_try := 1;
  end if;

  if v_att.status = 'submitted' and not v_replay then
    raise exception 'invalid_input';
  end if;

  if not v_replay then
    -- A new try: grade it on the server.
    v_correct := private.grade_answer(p_question_id, v_ans);

    if v_try = 1 then
      -- practice_count = distinct questions answered in any practice set (spec §1.6).
      perform pg_advisory_xact_lock(hashtextextended(v_uid::text || p_question_id::text, 0));
      v_counts := v_att.kind = 'practice' and not exists (
        select 1
        from public.attempt_answers aa
        join public.attempts a on a.id = aa.attempt_id
        where a.user_id = v_uid and a.kind = 'practice' and aa.question_id = p_question_id);

      insert into public.attempt_answers (attempt_id, question_id, answer, is_correct, time_ms, answered_at)
      values (p_attempt_id, p_question_id, jsonb_build_object('tries', jsonb_build_array(v_ans)),
              v_correct, v_time, now());

      if v_counts then
        insert into public.topic_progress (user_id, topic_id, practice_count)
        values (v_uid, v_att.topic_id, 1)
        on conflict (user_id, topic_id)
        do update set practice_count = public.topic_progress.practice_count + 1;
      end if;
    else
      update public.attempt_answers aa
      set answer      = jsonb_build_object('tries', v_tries || to_jsonb(v_ans)),
          is_correct  = v_correct,
          time_ms     = aa.time_ms + v_time,
          answered_at = now()
      where aa.attempt_id = p_attempt_id and aa.question_id = p_question_id;
    end if;
  end if;

  if v_att.kind = 'review' and v_att.status = 'in_progress' and (v_correct or v_try = 2) then
    if not exists (
      select 1 from public.attempt_questions aq
      left join public.attempt_answers aa on aa.attempt_id = aq.attempt_id and aa.question_id = aq.question_id
      where aq.attempt_id = p_attempt_id
        and not (coalesce(aa.is_correct, false)
          or pg_catalog.jsonb_array_length(coalesce(aa.answer -> 'tries', '[]'::jsonb)) >= 2)
    ) then
      update public.attempts set status = 'submitted', submitted_at = pg_catalog.now() where id = p_attempt_id;
    end if;
  end if;

  if v_correct or v_try = 2 then
    if v_q.type = 'mcq' then
      v_show := jsonb_build_object('choice', v_key.correct_answer ->> 'choice');
    else
      v_show := jsonb_build_object('text', v_key.correct_answer -> 'accepted' ->> 0);
    end if;
    return jsonb_build_object('is_correct', v_correct, 'try', v_try,
                              'key', v_show, 'explanation_md', v_key.explanation_md);
  end if;

  if v_q.type = 'mcq' then
    return jsonb_build_object('is_correct', false, 'try', 1, 'hint_md', v_q.hint_md,
                              'misconception_md', v_key.misconceptions ->> v_ans);
  end if;
  return jsonb_build_object('is_correct', false, 'try', 1, 'hint_md', v_q.hint_md,
                            'misconception_md', null);
end;
$$;
revoke execute on function public.check_practice_answer(uuid, uuid, text, int) from public, anon;
grant execute on function public.check_practice_answer(uuid, uuid, text, int) to authenticated;
