-- ═══════════════════════════════════════════════════════════════════
-- 👥 + 🕒 Kalar Guide — live users really counted, and opening hours
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- • active_users          one row per app install (random device id): language,
--                         platform, app version, last_seen. Written ONLY through
--                         app_presence_ping(); only the admin can read it.
-- • get_presence_stats()  numbers for the "live users" screen (admin only)
-- • dukan.opening_hours   opening hours of a place (jsonb), edited in the
--                         add/edit place form
-- ═══════════════════════════════════════════════════════════════════

alter table public.dukan add column if not exists opening_hours jsonb;

create table if not exists public.active_users (
  id          bigserial primary key,
  device_id   text not null,
  user_id     text,
  user_name   text,
  user_role   text default 'customer',
  app_version text,
  platform    text,
  language    text,
  neighborhood text,
  last_seen   timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- an older table may lack some of these columns
alter table public.active_users add column if not exists id bigserial;
alter table public.active_users add column if not exists user_id text;
alter table public.active_users add column if not exists user_name text;
alter table public.active_users add column if not exists user_role text default 'customer';
alter table public.active_users add column if not exists app_version text;
alter table public.active_users add column if not exists platform text;
alter table public.active_users add column if not exists language text;
alter table public.active_users add column if not exists neighborhood text;
alter table public.active_users add column if not exists last_seen timestamptz default now();
alter table public.active_users add column if not exists created_at timestamptz default now();

do $$ begin
  create unique index if not exists active_users_device_key on public.active_users (device_id);
exception when others then
  raise notice 'active_users_device_key not created (duplicate device ids?): %', sqlerrm;
end $$;
create index if not exists active_users_seen_idx on public.active_users (last_seen desc);

alter table public.active_users enable row level security;
do $$
declare p record;
begin
  for p in select policyname from pg_policies where schemaname = 'public' and tablename = 'active_users' loop
    execute format('drop policy %I on public.active_users', p.policyname);
  end loop;
end $$;
create policy admin_select on public.active_users for select using (public.app_is_admin());
create policy admin_delete on public.active_users for delete using (public.app_is_admin());
grant select, delete on public.active_users to authenticated;

-- the app calls this every minute while it is open
create or replace function public.app_presence_ping(
  p_device text, p_user text, p_name text, p_role text,
  p_version text, p_platform text, p_lang text, p_neighborhood text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if p_device is null or length(p_device) < 8 or length(p_device) > 64 then return; end if;
  insert into public.active_users
    (device_id, user_id, user_name, user_role, app_version, platform, language, neighborhood, last_seen)
  values
    (p_device, left(p_user, 64), left(p_name, 80), left(coalesce(p_role, 'customer'), 20),
     left(p_version, 20), left(p_platform, 20), left(p_lang, 5), left(p_neighborhood, 80), now())
  on conflict (device_id) do update set
    user_id = excluded.user_id, user_name = excluded.user_name, user_role = excluded.user_role,
    app_version = excluded.app_version, platform = excluded.platform,
    language = excluded.language, neighborhood = excluded.neighborhood, last_seen = now();
  -- keep the table small: forget installs not seen for 30 days
  if random() < 0.01 then
    delete from public.active_users where last_seen < now() - interval '30 days';
  end if;
end;
$$;
grant execute on function public.app_presence_ping(text, text, text, text, text, text, text, text) to anon, authenticated;

drop function if exists public.get_presence_stats();
create function public.get_presence_stats()
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not coalesce(public.app_is_admin(), false) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'online_now',  (select count(*) from public.active_users where last_seen > now() - interval '2 minutes'),
    'last_5min',   (select count(*) from public.active_users where last_seen > now() - interval '5 minutes'),
    'last_30min',  (select count(*) from public.active_users where last_seen > now() - interval '30 minutes'),
    'last_1hour',  (select count(*) from public.active_users where last_seen > now() - interval '1 hour'),
    'today',       (select count(*) from public.active_users
                     where (last_seen at time zone 'Asia/Baghdad')::date = (now() at time zone 'Asia/Baghdad')::date),
    'total_users', (select count(*) from public.active_users));
end;
$$;
grant execute on function public.get_presence_stats() to anon, authenticated;

-- live updates for the admin's "online now" counter
do $$ begin
  alter publication supabase_realtime add table public.active_users;
exception when others then
  raise notice 'realtime publication: %', sqlerrm;
end $$;

notify pgrst, 'reload schema';
