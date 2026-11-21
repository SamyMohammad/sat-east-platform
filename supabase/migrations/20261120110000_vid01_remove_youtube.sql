-- VID-01. Remove YouTube video support; teachers upload protected r2_hls videos from the dashboard.
-- From supabase/templates/rpc.sql and setting.sql. Forward-only; older migrations are untouched.

-- Leave an audit trail for the bulk delete (same action name as teacher_delete_video; actor is null = system).
insert into public.audit_log(actor,action,entity,entity_id,diff)
select null,'video.delete','topic_asset',a.id,
       pg_catalog.jsonb_build_object('before',pg_catalog.to_jsonb(a),'reason','vid01_remove_youtube')
  from public.topic_assets a where a.provider='youtube';

-- Dependents first (FKs are on delete restrict), then the youtube assets themselves.
delete from public.video_progress where asset_id in (select id from public.topic_assets where provider='youtube');
delete from public.video_chapters where asset_id in (select id from public.topic_assets where provider='youtube');
delete from private.video_keys where asset_id in (select id from public.topic_assets where provider='youtube');
update public.live_sessions set recording_asset_id=null
 where recording_asset_id in (select id from public.topic_assets where provider='youtube');
delete from public.topic_assets where provider='youtube';

alter table public.topic_assets drop constraint if exists topic_assets_provider_check;
alter table public.topic_assets add constraint topic_assets_provider_check check (provider in ('r2_hls'));

drop function if exists public.teacher_add_youtube_video(uuid,uuid,text,text,int);

insert into public.settings(key,value) values
 ('video_upload_max_source_mb','500'::jsonb),
 ('video_upload_max_duration_s','900'::jsonb)
on conflict(key) do nothing;

create or replace function public.teacher_list_videos(p_topic_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 if not exists(select 1 from public.topics where id=p_topic_id) then raise exception 'invalid_input'; end if;
 return (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'asset_id',a.id,'title',a.title,'subtopic_id',a.subtopic_id,'subtopic_title',s.title,
  'duration_s',a.duration_s,'size_mb',a.size_mb,'provider',a.provider,
  'ready',a.ready,'sort',a.sort) order by a.sort,a.id),'[]'::jsonb)
  from public.topic_assets a left join public.subtopics s on s.id=a.subtopic_id
  where a.topic_id=p_topic_id and a.kind='video');
end;
$fn$;
revoke execute on function public.teacher_list_videos(uuid) from public,anon;
grant execute on function public.teacher_list_videos(uuid) to authenticated;

create or replace function public.teacher_video_prefix(p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare v_provider text;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 select a.provider into v_provider from public.topic_assets a where a.id=p_asset_id and a.kind='video';
 if not found then raise exception 'invalid_input'; end if;
 return pg_catalog.jsonb_build_object('provider',v_provider,'r2_prefix','videos/'||p_asset_id::text);
end;
$fn$;
revoke execute on function public.teacher_video_prefix(uuid) from public,anon;
grant execute on function public.teacher_video_prefix(uuid) to authenticated;

create or replace function public.video_playback_grant(p_asset_id uuid)
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
 if v_asset.provider is distinct from 'r2_hls' then raise exception 'forbidden'; end if;
 v_limit := private.setting_int('rate_video_otp_per_min');
 if v_limit is null or v_limit<0 then raise exception 'invalid_input'; end if;
 v_key := 'video_playback_grant:'||v_uid;
 -- Count without raising so denied calls retain the increment (C-6 pattern).
 perform private.hit_rate_limit(v_key,null,60);
 select r.count into v_count from private.rate_limits r where r.key=v_key
  and r.window_start=pg_catalog.to_timestamp(pg_catalog.floor(extract(epoch from pg_catalog.now())/60)*60);
 if v_count>v_limit then return pg_catalog.jsonb_build_object('ok',false,'error','rate_limited'); end if;
 select p.last_position_s into v_resume from public.video_progress p where p.user_id=v_uid and p.asset_id=p_asset_id;
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
