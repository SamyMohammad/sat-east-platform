-- PAY-01 / PAY-04: public catalogue and course page (docs/07 §1.1, §7). From templates/rpc.sql +
-- templates/setting.sql. Deliberate exception to "authenticated only": both RPCs are public
-- (anon) because the catalogue is public; they return published rows only — no answer keys,
-- storage paths or order data.

insert into public.settings (key, value)
values ('currency_by_country', '{"EG": "EGP", "default": "USD"}'::jsonb)
on conflict (key) do nothing;

-- Country → currency through the setting (also used by create-checkout, P-2).
create or replace function private.currency_for(p_country text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(s.value ->> upper(p_country), s.value ->> 'default')
  from public.settings s
  where s.key = 'currency_by_country';
$$;

-- Signed-in profile country wins over the client's hint (docs/07 §7).
create or replace function private.visitor_currency(p_hint text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select private.currency_for(coalesce(
    (select p.country from public.profiles p where p.id = (select auth.uid())),
    nullif(upper(trim(p_hint)), '')
  ));
$$;

-- Active full price in the currency, else in the default currency, else null.
create or replace function private.course_price(p_course_id uuid, p_currency text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('currency', pr.currency, 'amount_minor', pr.amount_minor)
  from public.prices pr
  where pr.course_id = p_course_id and pr.kind = 'full' and pr.active
    and pr.currency in (p_currency, private.currency_for(null))
  order by (pr.currency = p_currency) desc, pr.created_at desc
  limit 1;
$$;

create or replace function public.get_catalogue(p_country text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_currency text := private.visitor_currency(p_country);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', c.id, 'code', c.code, 'slug', c.slug, 'title', c.title,
             'description', c.description,
             'topic_count', (select count(*) from public.topics t
                             where t.course_id = c.id and t.is_published),
             'free_topic_slug', (select t.slug from public.topics t
                                 where t.course_id = c.id and t.is_published and t.is_free_preview
                                 order by t.sort, t.title limit 1),
             'price', private.course_price(c.id, v_currency))
           order by c.sort, c.title)
    from public.courses c
    where c.is_published
  ), '[]'::jsonb);
end;
$$;

create or replace function public.get_course_page(p_slug text, p_country text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_course public.courses%rowtype;
begin
  select * into v_course from public.courses c where c.slug = p_slug and c.is_published;
  if not found then
    raise exception 'invalid_input';  -- same answer for unknown and unpublished
  end if;

  return jsonb_build_object(
    'id', v_course.id, 'code', v_course.code, 'slug', v_course.slug,
    'title', v_course.title, 'description', v_course.description,
    'price', private.course_price(v_course.id, private.visitor_currency(p_country)),
    'units', coalesce((
      select jsonb_agg(jsonb_build_object(
               'title', u.title,
               'topics', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'slug', t.slug, 'title', t.title, 'is_free_preview', t.is_free_preview,
                          'subtopic_count', (select count(*) from public.subtopics s where s.topic_id = t.id))
                        order by t.sort, t.title)
                 from public.topics t
                 where t.unit_id = u.id and t.is_published), '[]'::jsonb))
             order by u.sort, u.title)
      from public.units u
      where u.course_id = v_course.id
        and exists (select 1 from public.topics t where t.unit_id = u.id and t.is_published)
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function private.currency_for(text) from public, anon, authenticated;
revoke execute on function private.visitor_currency(text) from public, anon, authenticated;
revoke execute on function private.course_price(uuid, text) from public, anon, authenticated;

revoke execute on function public.get_catalogue(text) from public;
revoke execute on function public.get_course_page(text, text) from public;
grant execute on function public.get_catalogue(text) to anon, authenticated;
grant execute on function public.get_course_page(text, text) to anon, authenticated;
