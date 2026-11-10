-- 20261116_price_phone_match.sql
-- ڤێندەر دەتوانێت تەنها نرخی شوێنی خۆی بگۆڕێت (ئەدمین هەموو).
-- شوێن بە store_id یان ژمارەی تەلەفۆن بە ڤێندەرەوە دەبەسترێتەوە؛ پێشتر ژمارە
-- دەبوو ڕێک وەک یەک بنووسرێت. ئێستا تەنها ١٠ ژمارەی کۆتایی بەراورد دەکرێت،
-- بۆیە «0750 000 0002»، «+9647500000002» و «07500000002» یەک ژمارەن.

create or replace function public.app_phone_key(p text)
returns text
language sql immutable
as $$
  select nullif(right(regexp_replace(coalesce(p, ''), '\D', '', 'g'), 10), '');
$$;

create or replace function public.app_price_station_editable(p_station_id bigint)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.app_is_admin()
      or (public.app_role() = 'vendor' and exists (
            select 1 from public.dukan d
             where d.id = p_station_id
               and (d.id::text = public.app_store_id()
                    or (length(public.app_phone_key(d.phone::text)) = 10
                        and public.app_phone_key(d.phone::text)
                            = public.app_phone_key(public.app_phone())))));
$$;
grant execute on function public.app_price_station_editable(bigint) to anon, authenticated;
