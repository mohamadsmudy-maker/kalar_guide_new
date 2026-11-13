-- 20261118 — Fuel and currency types become data the admin can manage
-- (add, remove, rename, drag to reorder) instead of a fixed list in the app.
--
-- Safe to run more than once. The app keeps using its built-in list until this
-- table exists, so running it late breaks nothing.
--
-- Prices already stored on stations (dukan.fuel_prices / currency_prices) are
-- keyed by `key`. Removing a type only hides it; those stored prices stay.

create table if not exists public.price_types (
  id         bigserial primary key,
  kind       text not null check (kind in ('fuel', 'currency')),
  key        text not null,
  name_ku    text not null,
  name_ar    text,
  name_en    text,
  color      text not null default '#1E88E5',
  grp        text not null,                 -- fuel: fuel|gas   currency: fiat|gold
  emoji      text,                          -- fuel emoji / currency flag
  symbol     text,                          -- currency symbol
  per        numeric not null default 1,    -- currency: price is for this many units
  unit_ku    text,
  unit_ar    text,
  unit_en    text,
  sort_order int  not null default 0,
  created_at timestamptz not null default now(),
  unique (kind, key)
);

alter table public.price_types enable row level security;

drop policy if exists read_all     on public.price_types;
drop policy if exists admin_insert on public.price_types;
drop policy if exists admin_update on public.price_types;
drop policy if exists admin_delete on public.price_types;
create policy read_all     on public.price_types for select using (true);
create policy admin_insert on public.price_types for insert with check (public.app_is_admin());
create policy admin_update on public.price_types for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.price_types for delete using (public.app_is_admin());

grant select on public.price_types to anon, authenticated;
grant insert, update, delete on public.price_types to authenticated;
grant usage, select on sequence public.price_types_id_seq to authenticated;

-- the types the app shipped with (never overwrites rows the admin changed)
insert into public.price_types
  (kind, key, name_ku, name_ar, name_en, color, grp, emoji, symbol, per, unit_ku, unit_ar, unit_en, sort_order)
values
  ('fuel','normal','ئاسایی','عادي','Normal','#1E88E5','fuel','⛽',null,1,'لیتر','لتر','L',1),
  ('fuel','super','سوپەر','سوبر','Super','#EF4444','fuel','🔥',null,1,'لیتر','لتر','L',2),
  ('fuel','muhassen','محەسەن','محسن','Muhassen','#F59E0B','fuel','✨',null,1,'لیتر','لتر','L',3),
  ('fuel','oil','زەیت','زيت','Oil','#14B8A6','fuel','🛢️',null,1,'لیتر','لتر','L',4),
  ('fuel','iraqi_gas','گازی عێراقی','غاز عراقي','Iraqi Gas','#10B981','gas','🔵',null,1,'بوتڵ','قنينة','cylinder',5),
  ('fuel','iranian_gas','گازی ئێرانی','غاز إيراني','Iranian Gas','#8B5CF6','gas','🟣',null,1,'بوتڵ','قنينة','cylinder',6),
  ('fuel','gas','گاز','غاز','Gas','#EC4899','gas','🔴',null,1,'بوتڵ','قنينة','cylinder',7),
  ('currency','usd','دۆلاری ئەمەریکی','دولار أمريكي','US Dollar','#10B981','fiat','🇺🇸','$',100,'دۆلار','دولار','USD',1),
  ('currency','iqd','دیناری عێراقی','دينار عراقي','Iraqi Dinar','#14B8A6','fiat','🇮🇶','د.ع',1,'دینار','دينار','IQD',2),
  ('currency','eur','یۆرۆ','يورو','Euro','#1E88E5','fiat','🇪🇺','€',100,'یۆرۆ','يورو','EUR',3),
  ('currency','gbp','پاوەندی ئینگلیزی','جنيه إسترليني','British Pound','#8B5CF6','fiat','🇬🇧','£',100,'پاوەند','جنيه','GBP',4),
  ('currency','try','لیرەی تورکی','ليرة تركية','Turkish Lira','#EF4444','fiat','🇹🇷','₺',100,'لیرە','ليرة','TRY',5),
  ('currency','aed','دیرھەمی ئیماراتی','درهم إماراتي','UAE Dirham','#F59E0B','fiat','🇦🇪','د.إ',100,'دیرھەم','درهم','AED',6),
  ('currency','gold_24','زێڕی ٢٤ عەیار','ذهب عيار 24','Gold 24K','#FCD34D','gold','🥇','24K',1,'مسقاڵ','مثقال','mithqal',7),
  ('currency','gold_22','زێڕی ٢٢ عەیار','ذهب عيار 22','Gold 22K','#FBBF24','gold','🥇','22K',1,'مسقاڵ','مثقال','mithqal',8),
  ('currency','gold_21','زێڕی ٢١ عەیار','ذهب عيار 21','Gold 21K','#F59E0B','gold','🥇','21K',1,'مسقاڵ','مثقال','mithqal',9),
  ('currency','gold_18','زێڕی ١٨ عەیار','ذهب عيار 18','Gold 18K','#D97706','gold','🥇','18K',1,'مسقاڵ','مثقال','mithqal',10)
on conflict (kind, key) do nothing;

notify pgrst, 'reload schema';
