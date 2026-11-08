-- ═══════════════════════════════════════════════════════════════════
-- 🕌 Kalar Guide — official prayer times editable by the admin
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql (uses app_is_admin()).
--
-- One row per calendar day ('dd-MM', no year): prayer times repeat every
-- year to within a minute. A row here overrides the table built into the
-- app; deleting it falls back to the built-in table / calculation.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.prayer_times_official (
  day_month  text primary key
             check (day_month ~ '^(0[1-9]|[12][0-9]|3[01])-(0[1-9]|1[0-2])$'),
  fajr       text not null check (fajr    ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  sunrise    text not null check (sunrise ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  dhuhr      text not null check (dhuhr   ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  asr        text not null check (asr     ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  maghrib    text not null check (maghrib ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  isha       text not null check (isha    ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  updated_at timestamptz not null default now(),
  -- the six times must be in order (HH:MM strings sort correctly)
  check (fajr < sunrise and sunrise < dhuhr and dhuhr < asr
         and asr < maghrib and maghrib < isha)
);

create or replace function public.prayer_times_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists prayer_times_touch on public.prayer_times_official;
create trigger prayer_times_touch before update on public.prayer_times_official
  for each row execute function public.prayer_times_touch();

alter table public.prayer_times_official enable row level security;

drop policy if exists read_all    on public.prayer_times_official;
drop policy if exists admin_write on public.prayer_times_official;
create policy read_all on public.prayer_times_official for select using (true);
create policy admin_write on public.prayer_times_official for all
  using (public.app_is_admin()) with check (public.app_is_admin());

grant select on public.prayer_times_official to anon, authenticated;
grant insert, update, delete on public.prayer_times_official to authenticated;

-- 🔙 ROLLBACK
-- drop table public.prayer_times_official;
