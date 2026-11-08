-- ═══════════════════════════════════════════════════════════════════
-- 📍 Kalar Guide — where places come from + citizen place suggestions
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- • dukan.source       'manual' | 'osm' | 'suggestion'
-- • dukan.external_id  e.g. 'osm:node/123' — the same OpenStreetMap place
--                      can never be imported twice
-- • app_settings       small key/value table; everyone reads, admin writes
--                      ('place_suggestions_enabled' turns the feature on/off)
-- • place_suggestions  citizens suggest a place; only the admin sees all
--                      of them and approves (the app then adds it to dukan)
-- ═══════════════════════════════════════════════════════════════════

-- ── dukan ────────────────────────────────────────────────────────
alter table public.dukan add column if not exists source text not null default 'manual';
alter table public.dukan add column if not exists external_id text;
do $$ begin
  alter table public.dukan add constraint dukan_external_id_key unique (external_id);
exception when duplicate_table or duplicate_object then null;
end $$;

-- ── app_settings ─────────────────────────────────────────────────
create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb not null default 'null'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
drop policy if exists read_all     on public.app_settings;
drop policy if exists admin_insert on public.app_settings;
drop policy if exists admin_update on public.app_settings;
drop policy if exists admin_delete on public.app_settings;
create policy read_all     on public.app_settings for select using (true);
create policy admin_insert on public.app_settings for insert with check (public.app_is_admin());
create policy admin_update on public.app_settings for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.app_settings for delete using (public.app_is_admin());
grant select on public.app_settings to anon, authenticated;
grant insert, update, delete on public.app_settings to authenticated;

insert into public.app_settings (key, value) values ('place_suggestions_enabled', 'true')
on conflict (key) do nothing;

create or replace function public.app_setting_on(p_key text)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce((select s.value = 'true'::jsonb from public.app_settings s where s.key = p_key), false);
$$;
grant execute on function public.app_setting_on(text) to anon, authenticated;

-- ── place_suggestions ───────────────────────────────────────────
create table if not exists public.place_suggestions (
  id           bigserial primary key,
  name         text not null check (length(btrim(name)) between 2 and 120),
  category     text check (category is null or length(category) <= 120),
  latitude     double precision not null check (latitude between -90 and 90),
  longitude    double precision not null check (longitude between -180 and 180),
  address      text check (address is null or length(address) <= 200),
  phone        text check (phone is null or length(phone) <= 30),
  note         text check (note is null or length(note) <= 500),
  suggested_by text not null default public.app_user_id(),
  status       text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  dukan_id     bigint,
  reviewed_at  timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists place_suggestions_status_idx on public.place_suggestions (status, created_at desc);

-- at most 10 waiting suggestions per person (spam guard)
create or replace function public.app_pending_suggestions()
returns int
language sql stable security definer
set search_path = public
as $$
  select count(*)::int from public.place_suggestions
   where suggested_by = public.app_user_id() and status = 'pending';
$$;
grant execute on function public.app_pending_suggestions() to anon, authenticated;

alter table public.place_suggestions enable row level security;
drop policy if exists own_or_admin_read on public.place_suggestions;
drop policy if exists citizen_insert    on public.place_suggestions;
drop policy if exists admin_update      on public.place_suggestions;
drop policy if exists admin_delete      on public.place_suggestions;
create policy own_or_admin_read on public.place_suggestions for select
  using (public.app_is_admin() or suggested_by = public.app_user_id());
create policy citizen_insert on public.place_suggestions for insert
  with check (
    public.app_user_id() is not null
    and suggested_by = public.app_user_id()
    and status = 'pending' and dukan_id is null and reviewed_at is null
    and public.app_setting_on('place_suggestions_enabled')
    and public.app_pending_suggestions() < 10);
create policy admin_update on public.place_suggestions for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.place_suggestions for delete using (public.app_is_admin());
grant select, insert on public.place_suggestions to authenticated;
grant update, delete on public.place_suggestions to authenticated;
grant usage, select on sequence public.place_suggestions_id_seq to authenticated;

-- 🔙 ROLLBACK
-- drop table public.place_suggestions;
-- drop function public.app_pending_suggestions();
-- drop function public.app_setting_on(text);
-- drop table public.app_settings;
-- alter table public.dukan drop constraint dukan_external_id_key;
-- alter table public.dukan drop column external_id, drop column source;
