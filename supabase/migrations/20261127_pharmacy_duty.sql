-- ═══════════════════════════════════════════════════════════════════
-- 💊 Kalar Guide — on-duty (night) pharmacies
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- هەر ڕیزێک = دەرمانخانەیەک کە لە شەوی duty_date دا ئێشکگرە (تا بەیانی دواتر).
-- ناو/ژمارە/ناونیشان/شوێن کاتی زیادکردن لە dukan ـەوە کۆپی دەکرێن (یان بە
-- دەست دەنووسرێن)، بۆیە دەرمانخانەیەک کە لە شوێنەکاندا نییەش دەتوانرێت دابنرێت.
-- هەمووان دەیبینن؛ تەنها ئەدمین دەیگۆڕێت.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.pharmacy_duty (
  id          bigserial primary key,
  duty_date   date not null,
  dukan_id    bigint references public.dukan(id) on delete set null,
  name        text not null check (length(btrim(name)) between 1 and 200),
  phone       text,
  address     text,
  latitude    double precision,
  longitude   double precision,
  note        text,
  created_at  timestamptz not null default now()
);

create index if not exists pharmacy_duty_date_idx on public.pharmacy_duty (duty_date);

alter table public.pharmacy_duty enable row level security;

drop policy if exists read_all     on public.pharmacy_duty;
drop policy if exists admin_insert on public.pharmacy_duty;
drop policy if exists admin_update on public.pharmacy_duty;
drop policy if exists admin_delete on public.pharmacy_duty;

create policy read_all     on public.pharmacy_duty for select using (true);
create policy admin_insert on public.pharmacy_duty for insert with check (public.app_is_admin());
create policy admin_update on public.pharmacy_duty for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.pharmacy_duty for delete using (public.app_is_admin());

grant select on public.pharmacy_duty to anon, authenticated;
grant insert, update, delete on public.pharmacy_duty to authenticated;
grant usage, select on sequence public.pharmacy_duty_id_seq to authenticated;

-- 🔙 ROLLBACK
-- drop table public.pharmacy_duty;
