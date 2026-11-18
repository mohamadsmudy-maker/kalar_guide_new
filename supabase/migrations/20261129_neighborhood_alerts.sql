-- ═══════════════════════════════════════════════════════════════════
-- 📍 Kalar Guide — alerts for one neighborhood (water/power cuts...)
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- ئەدمین ئاگادارییەک بۆ گەڕەکێک دەنووسێت؛ send-neighborhood-alert بۆ
-- topic ـی nbh_<neighborhood_id> دەینێرێت (ئەوانەی ئەو گەڕەکەیان هەڵبژاردووە).
-- notified_at = قفڵی یەکجار ناردن.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.neighborhood_alerts (
  id                bigserial primary key,
  neighborhood_id   bigint not null,
  neighborhood_name text,
  title             text not null check (length(btrim(title)) between 1 and 200),
  body              text,
  created_at        timestamptz not null default now(),
  notified_at       timestamptz
);

create index if not exists neighborhood_alerts_nbh_idx
  on public.neighborhood_alerts (neighborhood_id, created_at desc);

alter table public.neighborhood_alerts enable row level security;

drop policy if exists read_all     on public.neighborhood_alerts;
drop policy if exists admin_insert on public.neighborhood_alerts;
drop policy if exists admin_update on public.neighborhood_alerts;
drop policy if exists admin_delete on public.neighborhood_alerts;

create policy read_all     on public.neighborhood_alerts for select using (true);
create policy admin_insert on public.neighborhood_alerts for insert with check (public.app_is_admin());
create policy admin_update on public.neighborhood_alerts for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.neighborhood_alerts for delete using (public.app_is_admin());

grant select on public.neighborhood_alerts to anon, authenticated;
grant insert, update, delete on public.neighborhood_alerts to authenticated;
grant usage, select on sequence public.neighborhood_alerts_id_seq to authenticated;

-- 🔙 ROLLBACK
-- drop table public.neighborhood_alerts;
