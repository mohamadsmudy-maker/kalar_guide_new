-- ═══════════════════════════════════════════════════════════════════
-- 💱⛽ Kalar Guide — saving currency / fuel prices through the server
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- Why: the app updated dukan.currency_prices / fuel_prices directly and
-- then inserted a history row. Under RLS that failed silently when the
-- station belongs to the vendor through dukan.phone (that is how the app
-- lists a vendor's stations) but not through app_users.store_id.
--
-- These functions do the update + history row in one transaction and
-- return a status the app can show:
--   ok | not_logged_in | forbidden | not_found | invalid
-- ═══════════════════════════════════════════════════════════════════

-- Admin, or an approved vendor whose store_id is this station or whose
-- phone is the station's phone.
create or replace function public.app_can_edit_station(p_station_id bigint)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.app_is_admin()
      or (public.app_role() = 'vendor' and exists (
            select 1 from public.dukan d
             where d.id = p_station_id
               and (d.id::text = public.app_store_id()
                    or (coalesce(d.phone::text, '') <> ''
                        and d.phone::text = public.app_phone()))));
$$;
grant execute on function public.app_can_edit_station(bigint) to anon, authenticated;

-- number from a json value, or null if it is not a number
create or replace function public.app_json_num(v jsonb)
returns numeric
language sql immutable
as $$
  select case
    when jsonb_typeof(v) = 'number' then (v #>> '{}')::numeric
    when jsonb_typeof(v) = 'string' and (v #>> '{}') ~ '^\s*-?\d+(\.\d+)?\s*$'
      then (v #>> '{}')::numeric
  end;
$$;

create or replace function public.app_update_currency_price(
  p_station_id bigint,
  p_type text,
  p_buy numeric,
  p_sell numeric,
  p_notes text default null)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  cur jsonb;
  old jsonb;
  who text;
begin
  if coalesce(btrim(p_type), '') = '' or coalesce(p_buy, 0) < 0 or coalesce(p_sell, 0) < 0
     or (coalesce(p_buy, 0) = 0 and coalesce(p_sell, 0) = 0) then
    return 'invalid';
  end if;
  if public.app_role() = 'guest' then return 'not_logged_in'; end if;

  select coalesce(d.currency_prices::jsonb, '{}'::jsonb) into cur
    from public.dukan d where d.id = p_station_id for update;
  if not found then return 'not_found'; end if;
  if not public.app_can_edit_station(p_station_id) then return 'forbidden'; end if;

  if jsonb_typeof(cur) <> 'object' then cur := '{}'::jsonb; end if;
  old := cur -> p_type;

  update public.dukan
     set currency_prices = cur || jsonb_build_object(p_type, jsonb_build_object(
           'buy', p_buy,
           'sell', p_sell,
           'updated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
   where id = p_station_id;

  select u.name::text into who from public.app_users u where u.id::text = public.app_user_id();

  insert into public.currency_price_history
    (station_id, currency_type, old_buy_price, new_buy_price,
     old_sell_price, new_sell_price, updated_by_name, notes)
  values
    (p_station_id, p_type, public.app_json_num(old -> 'buy'), p_buy,
     public.app_json_num(old -> 'sell'), p_sell, coalesce(who, 'نەناسراو'),
     nullif(btrim(p_notes), ''));

  return 'ok';
end;
$$;
grant execute on function public.app_update_currency_price(bigint, text, numeric, numeric, text)
  to anon, authenticated;

create or replace function public.app_update_fuel_price(
  p_station_id bigint,
  p_type text,
  p_price numeric,
  p_notes text default null)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  cur jsonb;
  who text;
begin
  if coalesce(btrim(p_type), '') = '' or coalesce(p_price, 0) <= 0 then
    return 'invalid';
  end if;
  if public.app_role() = 'guest' then return 'not_logged_in'; end if;

  select coalesce(d.fuel_prices::jsonb, '{}'::jsonb) into cur
    from public.dukan d where d.id = p_station_id for update;
  if not found then return 'not_found'; end if;
  if not public.app_can_edit_station(p_station_id) then return 'forbidden'; end if;

  if jsonb_typeof(cur) <> 'object' then cur := '{}'::jsonb; end if;

  update public.dukan
     set fuel_prices = cur || jsonb_build_object(p_type, p_price)
   where id = p_station_id;

  select u.name::text into who from public.app_users u where u.id::text = public.app_user_id();

  insert into public.fuel_price_history
    (station_id, fuel_type, old_price, new_price, updated_by_name, notes)
  values
    (p_station_id, p_type, public.app_json_num(cur -> p_type), p_price,
     coalesce(who, 'نەناسراو'), nullif(btrim(p_notes), ''));

  return 'ok';
end;
$$;
grant execute on function public.app_update_fuel_price(bigint, text, numeric, text)
  to anon, authenticated;

-- 🔙 ROLLBACK
-- drop function public.app_update_fuel_price(bigint, text, numeric, text);
-- drop function public.app_update_currency_price(bigint, text, numeric, numeric, text);
-- drop function public.app_json_num(jsonb);
-- drop function public.app_can_edit_station(bigint);
