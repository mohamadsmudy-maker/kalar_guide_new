-- ═══════════════════════════════════════════════════════════════════
-- ⛽💱 Kalar Guide — چالاک/ناچالاککردنی نرخی بەنزینخانە و نوسینگەی دراو
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261115_places_sources.sql (app_settings). Safe to run more than once.
--
-- dukan.prices_active = false  → نرخەکانی ئەو شوێنە لە لیستی هاوڵاتیان
-- دەشاردرێنەوە. ئەگەر هەموو بەنزینخانەکان (یان هەموو نوسینگەکان) ناچالاک بن،
-- ئەپەکە «نرخی گشتی» پیشان دەدات کە ئەدمین لە app_settings دەینووسێت:
--   general_fuel_prices      {"normal": 1000, ...}
--   general_currency_prices  {"usd": {"buy": .., "sell": .., "updated_at": ..}, ...}
-- ═══════════════════════════════════════════════════════════════════

alter table public.dukan
  add column if not exists prices_active boolean not null default true;

-- ڤێندەر دەتوانێت ڕیزی خۆی لە dukan بگۆڕێت، بەڵام ئەم ستوونە تەنها هی ئەدمینە.
-- (auth.uid() is null = SQL Editor / service role)
create or replace function public.app_guard_prices_active()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.prices_active is distinct from old.prices_active
     and auth.uid() is not null
     and not public.app_is_admin() then
    new.prices_active := old.prices_active;
  end if;
  return new;
end;
$$;

drop trigger if exists dukan_guard_prices_active on public.dukan;
create trigger dukan_guard_prices_active
  before update on public.dukan
  for each row execute function public.app_guard_prices_active();

-- 🔙 ROLLBACK
-- drop trigger dukan_guard_prices_active on public.dukan;
-- drop function public.app_guard_prices_active();
-- alter table public.dukan drop column prices_active;
