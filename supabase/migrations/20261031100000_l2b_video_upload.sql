-- C-2 / SEC-01. From supabase/templates/rpc.sql and setting.sql.
insert into public.settings(key,value) values ('video_upload_url_ttl_s','900'::jsonb)
on conflict(key) do nothing;

create function public.teacher_video_upload_grant(p_asset_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if not public.is_teacher() then raise exception 'forbidden'; end if;
 select a.id into v_id from public.topic_assets a
 where a.id=p_asset_id and a.kind='video' and a.provider='r2_hls' and not a.ready;
 if not found then raise exception 'invalid_input'; end if;
 return pg_catalog.jsonb_build_object('r2_prefix','videos/'||v_id::text,
  'ttl_s',private.setting_int('video_upload_url_ttl_s'));
end;
$fn$;
revoke execute on function public.teacher_video_upload_grant(uuid) from public,anon;
grant execute on function public.teacher_video_upload_grant(uuid) to authenticated;
