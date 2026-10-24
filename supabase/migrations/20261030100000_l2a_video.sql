-- LRN-02 / SEC-01 / C-2. From supabase/templates/rpc.sql and setting.sql.
alter table public.topic_assets
 add column provider text check (provider in ('r2_hls','youtube')),
 add column size_mb int check (size_mb >= 0);
grant select(provider,size_mb,duration_s) on public.topic_assets to authenticated;

drop policy "topic_assets: student with topic access" on public.topic_assets;
create policy "topic_assets: student with topic access" on public.topic_assets
 for select to authenticated using (public.has_access_topic(topic_id)
  and (kind<>'video' or ready)
  and (kind<>'notes' or (ready and private.notes_object_readable(topic_id::text||'/'||id::text||'.pdf'))));

insert into public.settings(key,value) values
 ('video_storage_cap_mb','9216'::jsonb),
 ('video_key_ttl_s','300'::jsonb),
 ('video_playlist_ttl_s','14400'::jsonb),
 ('video_progress_interval_s','15'::jsonb),
 ('rate_video_otp_per_min','30'::jsonb)
on conflict(key) do nothing;

-- The api Edge Function calls this with the service role after verifying a playback token.
create function public.service_video_key(p_asset_id uuid)
returns jsonb
language sql stable security definer set search_path='' as $fn$
 select pg_catalog.jsonb_build_object('key_hex',pg_catalog.encode(k.key,'hex'),'r2_prefix',k.r2_prefix)
 from private.video_keys k where k.asset_id=p_asset_id;
$fn$;
revoke all on function public.service_video_key(uuid) from public,anon,authenticated;
grant execute on function public.service_video_key(uuid) to service_role;

create function private.video_satisfied(p_uid uuid,p_topic_id uuid)
returns boolean language sql stable set search_path='' as $fn$
 select not exists (
  select 1 from public.topic_assets a
  left join public.video_progress p on p.asset_id=a.id and p.user_id=p_uid
  where a.topic_id=p_topic_id and a.kind='video' and a.ready
   and coalesce(p.pct,0)<private.setting_int('video_done_pct')
 ) or exists (
  select 1 from public.topic_progress p where p.user_id=p_uid and p.topic_id=p_topic_id
   and (p.practice_count>=private.setting_int('practice_min') or p.quiz_passed_at is not null)
 );
$fn$;
revoke all on function private.video_satisfied(uuid,uuid) from public,anon,authenticated,service_role;

create or replace function private.require_notes_opened(p_uid uuid,p_topic_id uuid)
returns void language plpgsql stable set search_path='' as $fn$
begin
 if not private.video_satisfied(p_uid,p_topic_id) then raise exception 'video_needed'; end if;
 if not private.notes_satisfied(p_uid,p_topic_id) then raise exception 'notes_needed'; end if;
end;
$fn$;
revoke all on function private.require_notes_opened(uuid,uuid) from public,anon,authenticated,service_role;

create function public.teacher_video_quota()
returns jsonb language plpgsql security definer set search_path='' as $fn$
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 return pg_catalog.jsonb_build_object('used_mb',(
  select coalesce(sum(a.size_mb),0) from public.topic_assets a where a.kind='video'),
  'cap_mb',private.setting_int('video_storage_cap_mb'));
end;
$fn$;
revoke execute on function public.teacher_video_quota() from public,anon;
grant execute on function public.teacher_video_quota() to authenticated;

create function public.teacher_create_video_asset(p_topic_id uuid,p_subtopic_id uuid,p_title text,p_duration_s int,p_size_mb int)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 v_asset public.topic_assets%rowtype;
 v_cap int;
 v_used bigint;
 v_sort int;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_title is null or pg_catalog.length(pg_catalog.btrim(p_title)) not between 1 and 120
  or p_duration_s is null or p_duration_s<=0 or p_size_mb is null or p_size_mb<0 then
  raise exception 'invalid_input';
 end if;
 -- All reservations serialize on this row, including reservations for other topics.
 select s.value::int into v_cap from public.settings s where s.key='video_storage_cap_mb' for update;
 if v_cap is null or v_cap<0 then raise exception 'invalid_input'; end if;
 perform 1 from public.topics where id=p_topic_id for update;
 if not found then raise exception 'invalid_input'; end if;
 if p_subtopic_id is not null then
  perform 1 from public.subtopics where id=p_subtopic_id and topic_id=p_topic_id for share;
  if not found then raise exception 'invalid_input'; end if;
 end if;
 select coalesce(sum(a.size_mb),0) into v_used from public.topic_assets a where a.kind='video';
 if v_used+p_size_mb>v_cap then
  return pg_catalog.jsonb_build_object('ok',false,'error','quota_exceeded','used_mb',v_used,'cap_mb',v_cap);
 end if;
 select coalesce(max(a.sort),0)+1 into v_sort from public.topic_assets a where a.topic_id=p_topic_id and a.kind='video';
 insert into public.topic_assets(topic_id,subtopic_id,kind,title,sort,provider,duration_s,size_mb,ready)
 values(p_topic_id,p_subtopic_id,'video',pg_catalog.btrim(p_title),v_sort,'r2_hls',p_duration_s,p_size_mb,false)
 returning * into v_asset;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'video.create','topic_asset',v_asset.id,pg_catalog.jsonb_build_object('after',pg_catalog.to_jsonb(v_asset)));
 return pg_catalog.jsonb_build_object('ok',true,'asset_id',v_asset.id);
end;
$fn$;
revoke execute on function public.teacher_create_video_asset(uuid,uuid,text,int,int) from public,anon;
grant execute on function public.teacher_create_video_asset(uuid,uuid,text,int,int) to authenticated;

create function public.teacher_confirm_video_asset(p_asset_id uuid,p_key_hex text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_before public.topic_assets%rowtype; v_after public.topic_assets%rowtype;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_key_hex is null or p_key_hex !~ '^[A-Fa-f0-9]{32}$' then raise exception 'invalid_input'; end if;
 select * into v_before from public.topic_assets where id=p_asset_id and kind='video' and provider='r2_hls' for update;
 if not found then raise exception 'invalid_input'; end if;
 -- A retried confirmation must never rotate a key for already uploaded ciphertext.
 if v_before.ready then
  if not exists(select 1 from private.video_keys k where k.asset_id=p_asset_id
   and k.key=pg_catalog.decode(p_key_hex,'hex')) then raise exception 'invalid_input'; end if;
  return pg_catalog.jsonb_build_object('ok',true);
 end if;
 insert into private.video_keys(asset_id,key,r2_prefix)
 values(p_asset_id,pg_catalog.decode(p_key_hex,'hex'),'videos/'||p_asset_id::text);
 update public.topic_assets set ready=true,updated_at=pg_catalog.now() where id=p_asset_id returning * into v_after;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'video.confirm','topic_asset',p_asset_id,
  pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(v_before),'after',pg_catalog.to_jsonb(v_after)));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$fn$;
revoke execute on function public.teacher_confirm_video_asset(uuid,text) from public,anon;
grant execute on function public.teacher_confirm_video_asset(uuid,text) to authenticated;

create function public.teacher_add_youtube_video(p_topic_id uuid,p_subtopic_id uuid,p_title text,p_youtube_id text,p_duration_s int)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_asset public.topic_assets%rowtype; v_sort int;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_title is null or pg_catalog.length(pg_catalog.btrim(p_title)) not between 1 and 120
  or p_duration_s is null or p_duration_s<=0 or p_youtube_id is null or p_youtube_id !~ '^[A-Za-z0-9_-]{11}$' then
  raise exception 'invalid_input';
 end if;
 perform 1 from public.topics where id=p_topic_id for update;
 if not found then raise exception 'invalid_input'; end if;
 if p_subtopic_id is not null then
  perform 1 from public.subtopics where id=p_subtopic_id and topic_id=p_topic_id for share;
  if not found then raise exception 'invalid_input'; end if;
 end if;
 select coalesce(max(a.sort),0)+1 into v_sort from public.topic_assets a where a.topic_id=p_topic_id and a.kind='video';
 insert into public.topic_assets(topic_id,subtopic_id,kind,title,sort,provider,video_provider_id,duration_s,size_mb,ready)
 values(p_topic_id,p_subtopic_id,'video',pg_catalog.btrim(p_title),v_sort,'youtube',p_youtube_id,p_duration_s,0,true)
 returning * into v_asset;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'video.create','topic_asset',v_asset.id,pg_catalog.jsonb_build_object('after',pg_catalog.to_jsonb(v_asset)));
 return pg_catalog.jsonb_build_object('ok',true,'asset_id',v_asset.id);
end;
$fn$;
revoke execute on function public.teacher_add_youtube_video(uuid,uuid,text,text,int) from public,anon;
grant execute on function public.teacher_add_youtube_video(uuid,uuid,text,text,int) to authenticated;

create function public.teacher_update_video(p_asset_id uuid,p_title text,p_subtopic_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_before public.topic_assets%rowtype; v_after public.topic_assets%rowtype;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_title is null or pg_catalog.length(pg_catalog.btrim(p_title)) not between 1 and 120 then raise exception 'invalid_input'; end if;
 select * into v_before from public.topic_assets where id=p_asset_id and kind='video' for update;
 if not found then raise exception 'invalid_input'; end if;
 if p_subtopic_id is not null then
  perform 1 from public.subtopics where id=p_subtopic_id and topic_id=v_before.topic_id for share;
  if not found then raise exception 'invalid_input'; end if;
 end if;
 update public.topic_assets set title=pg_catalog.btrim(p_title),subtopic_id=p_subtopic_id,updated_at=pg_catalog.now()
 where id=p_asset_id returning * into v_after;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'video.update','topic_asset',p_asset_id,
  pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(v_before),'after',pg_catalog.to_jsonb(v_after)));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$fn$;
revoke execute on function public.teacher_update_video(uuid,text,uuid) from public,anon;
grant execute on function public.teacher_update_video(uuid,text,uuid) to authenticated;


create function public.teacher_reorder_videos(p_topic_id uuid,p_ids uuid[])
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_current uuid[]; v_expected uuid[]; v_before jsonb;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if p_ids is null or pg_catalog.array_ndims(p_ids)>1 then raise exception 'invalid_input'; end if;
 perform 1 from public.topics where id=p_topic_id for update;
 if not found then raise exception 'invalid_input'; end if;
 perform 1 from public.topic_assets where topic_id=p_topic_id and kind='video' order by id for update;
 select coalesce(pg_catalog.array_agg(id order by id),'{}'::uuid[]),
  coalesce(pg_catalog.jsonb_agg(id order by sort,id),'[]'::jsonb)
 into v_current,v_before from public.topic_assets where topic_id=p_topic_id and kind='video';
 select coalesce(pg_catalog.array_agg(id order by id),'{}'::uuid[]) into v_expected from pg_catalog.unnest(p_ids) id;
 if v_current is distinct from v_expected then raise exception 'invalid_input'; end if;
 update public.topic_assets a set sort=i.position::int,updated_at=pg_catalog.now()
 from pg_catalog.unnest(p_ids) with ordinality i(id,position) where a.id=i.id;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'video.reorder','topic',p_topic_id,pg_catalog.jsonb_build_object('before',v_before,'after',p_ids));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$fn$;
revoke execute on function public.teacher_reorder_videos(uuid,uuid[]) from public,anon;
grant execute on function public.teacher_reorder_videos(uuid,uuid[]) to authenticated;


-- Copied from 20261028100000; only videos and video_done are added.
create or replace function public.get_topic(p_topic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_uid uuid := auth.uid();
  v_quiz jsonb;
  v_topic record;
  v_label text;
  v_notes jsonb;
  v_videos jsonb;
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
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('asset_id', a.id, 'title', a.title,
    'subtopic_title', s.title, 'page_count', a.page_count) order by a.sort, a.id), '[]'::jsonb)
  into v_notes from public.topic_assets a left join public.subtopics s on s.id = a.subtopic_id
  where a.topic_id = p_topic_id and a.kind = 'notes' and a.ready;
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'asset_id',a.id,'title',a.title,'subtopic_title',s.title,'duration_s',a.duration_s,
    'provider',a.provider,'pct',coalesce(p.pct,0),'last_position_s',coalesce(p.last_position_s,0)
    ) order by a.sort,a.id),'[]'::jsonb)
  into v_videos from public.topic_assets a
  left join public.subtopics s on s.id=a.subtopic_id
  left join public.video_progress p on p.asset_id=a.id and p.user_id=v_uid
  where a.topic_id=p_topic_id and a.kind='video' and a.ready;
  return pg_catalog.jsonb_build_object('id', p_topic_id, 'title', v_topic.title, 'slug', v_topic.slug,
    'sort_label', v_label, 'status', v_topic.status,
    'practice', pg_catalog.jsonb_build_object('count', v_quiz -> 'practice_count', 'min', v_quiz -> 'practice_min'),
    'quiz', v_quiz,
    'videos',v_videos,'video_done',private.video_satisfied(v_uid,p_topic_id),
    'notes', v_notes, 'notes_done', private.notes_satisfied(v_uid, p_topic_id));
end;
$fn$;
revoke execute on function public.get_topic(uuid) from public, anon;
grant execute on function public.get_topic(uuid) to authenticated;

create function public.teacher_list_videos(p_topic_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if not exists(select 1 from public.topics where id=p_topic_id) then raise exception 'invalid_input'; end if;
 return (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'asset_id',a.id,'title',a.title,'subtopic_id',a.subtopic_id,'subtopic_title',s.title,
  'duration_s',a.duration_s,'size_mb',a.size_mb,'provider',a.provider,
  'youtube_id',a.video_provider_id,'ready',a.ready,'sort',a.sort) order by a.sort,a.id),'[]'::jsonb)
  from public.topic_assets a left join public.subtopics s on s.id=a.subtopic_id
  where a.topic_id=p_topic_id and a.kind='video');
end;
$fn$;
revoke execute on function public.teacher_list_videos(uuid) from public,anon;
grant execute on function public.teacher_list_videos(uuid) to authenticated;

create function public.teacher_video_prefix(p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare v_provider text;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 select a.provider into v_provider from public.topic_assets a where a.id=p_asset_id and a.kind='video';
 if not found then raise exception 'invalid_input'; end if;
 return pg_catalog.jsonb_build_object('provider',v_provider,
  'r2_prefix',case when v_provider='r2_hls' then 'videos/'||p_asset_id::text else null end);
end;
$fn$;
revoke execute on function public.teacher_video_prefix(uuid) from public,anon;
grant execute on function public.teacher_video_prefix(uuid) to authenticated;

create function public.teacher_delete_video(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_before public.topic_assets%rowtype;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 select * into v_before from public.topic_assets where id=p_asset_id and kind='video' for update;
 if not found then raise exception 'invalid_input'; end if;
 delete from public.video_progress where asset_id=p_asset_id;
 delete from public.video_chapters where asset_id=p_asset_id;
 delete from private.video_keys where asset_id=p_asset_id;
 delete from public.topic_assets where id=p_asset_id;
 insert into public.audit_log(actor,action,entity,entity_id,diff)
 values(auth.uid(),'video.delete','topic_asset',p_asset_id,pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(v_before)));
 return pg_catalog.jsonb_build_object('ok',true);
end;
$fn$;
revoke execute on function public.teacher_delete_video(uuid) from public,anon;
grant execute on function public.teacher_delete_video(uuid) to authenticated;

create function public.video_playback_grant(p_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 v_uid uuid := auth.uid();
 v_asset public.topic_assets%rowtype;
 v_limit int;
 v_count int;
 v_resume int;
 v_name text;
 v_key text;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select a.* into v_asset from public.topic_assets a where a.id=p_asset_id and a.kind='video' and a.ready;
 if not found then raise exception 'forbidden'; end if;
 if not public.has_access_topic(v_asset.topic_id) then raise exception 'forbidden'; end if;
 perform private.practice_access(v_uid,v_asset.topic_id);
 if not private.device_allowed() then raise exception 'device_revoked'; end if;
 if v_asset.provider is null or v_asset.provider not in ('r2_hls','youtube') then raise exception 'forbidden'; end if;
 v_limit := private.setting_int('rate_video_otp_per_min');
 if v_limit is null or v_limit<0 then raise exception 'invalid_input'; end if;
 v_key := 'video_playback_grant:'||v_uid;
 -- Count without raising so denied calls retain the increment (C-6 pattern).
 perform private.hit_rate_limit(v_key,null,60);
 select r.count into v_count from private.rate_limits r where r.key=v_key
  and r.window_start=pg_catalog.to_timestamp(pg_catalog.floor(extract(epoch from pg_catalog.now())/60)*60);
 if v_count>v_limit then return pg_catalog.jsonb_build_object('ok',false,'error','rate_limited'); end if;
 select p.last_position_s into v_resume from public.video_progress p where p.user_id=v_uid and p.asset_id=p_asset_id;
 if v_asset.provider='youtube' then
  return pg_catalog.jsonb_build_object('ok',true,'provider','youtube',
   'youtube_id',v_asset.video_provider_id,'resume_s',coalesce(v_resume,0));
 end if;
 select p.full_name into v_name from public.profiles p where p.id=v_uid;
 return pg_catalog.jsonb_build_object('ok',true,'provider','r2_hls','asset_id',p_asset_id,'user_id',v_uid,
  'watermark',pg_catalog.jsonb_build_object('name',v_name,
   'short_id',pg_catalog.upper(pg_catalog.left(pg_catalog.replace(v_uid::text,'-',''),6))),
  'key_ttl_s',private.setting_int('video_key_ttl_s'),
  'playlist_ttl_s',private.setting_int('video_playlist_ttl_s'),'resume_s',coalesce(v_resume,0));
end;
$fn$;
revoke execute on function public.video_playback_grant(uuid) from public,anon;
grant execute on function public.video_playback_grant(uuid) to authenticated;

create function public.save_video_progress(p_asset_id uuid,p_from_s int,p_to_s int,p_position_s int)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
 v_uid uuid := auth.uid();
 v_asset public.topic_assets%rowtype;
 v_from int;
 v_to int;
 v_ranges int4range[];
 v_merged int4range[];
 v_covered bigint;
 v_pct int;
 v_interval int;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select a.* into v_asset from public.topic_assets a where a.id=p_asset_id and a.kind='video' and a.ready for share;
 if not found then raise exception 'forbidden'; end if;
 if not public.has_access_topic(v_asset.topic_id) then raise exception 'forbidden'; end if;
 perform private.practice_access(v_uid,v_asset.topic_id);
 if not private.device_allowed() then raise exception 'device_revoked'; end if;
 v_interval := private.setting_int('video_progress_interval_s');
 if p_from_s is null or p_to_s is null or p_position_s is null or v_asset.duration_s is null
  or v_asset.duration_s<=0 or v_interval is null or v_interval<=0
  or p_to_s<p_from_s or p_to_s::bigint-p_from_s::bigint>2::bigint*v_interval+5 then
  raise exception 'invalid_input';
 end if;
 v_from := greatest(0,least(p_from_s,v_asset.duration_s));
 v_to := greatest(0,least(p_to_s,v_asset.duration_s));
 -- The unique row plus row lock prevents concurrent heartbeats losing coverage.
 insert into public.video_progress(user_id,asset_id) values(v_uid,p_asset_id) on conflict(user_id,asset_id) do nothing;
 select p.watched_ranges into v_ranges from public.video_progress p
 where p.user_id=v_uid and p.asset_id=p_asset_id for update;
 select coalesce(pg_catalog.array_agg(r order by pg_catalog.lower(r)),'{}'::int4range[]),
  coalesce(sum(pg_catalog.upper(r)::bigint-pg_catalog.lower(r)),0)
 into v_merged,v_covered
 from pg_catalog.unnest((select pg_catalog.range_agg(x.r)
  from pg_catalog.unnest(v_ranges||array[pg_catalog.int4range(v_from,v_to,'[)')]) x(r))) r;
 v_pct := least(100,(v_covered*100/v_asset.duration_s)::int);
 update public.video_progress set watched_ranges=v_merged,pct=v_pct,
  last_position_s=greatest(0,least(p_position_s,v_asset.duration_s)),updated_at=pg_catalog.now()
 where user_id=v_uid and asset_id=p_asset_id;
 return pg_catalog.jsonb_build_object('pct',v_pct,'done',v_pct>=private.setting_int('video_done_pct'));
end;
$fn$;
revoke execute on function public.save_video_progress(uuid,int,int,int) from public,anon;
grant execute on function public.save_video_progress(uuid,int,int,int) to authenticated;
