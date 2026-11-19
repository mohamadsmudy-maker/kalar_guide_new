-- ═══════════════════════════════════════════════════════════════════
-- 📢 Kalar Guide — sponsored slides in the home slider
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- ڕیکلامی بازرگانانی ناوخۆ لە سلایدی پەیجی سەرەکی، لە نێوان هەواڵەکاندا.
-- هەمووان تەنها ڕیکلامی چالاک و ناو ماوەکەی دەبینن؛ ئەدمین هەموو دەبینێت
-- و دەیگۆڕێت. بینین و کرتە بە app_sponsored_event() دەژمێردرێن (تەنها ژمارە،
-- هیچ زانیارییەکی بەکارهێنەر).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.sponsored_slides (
  id            bigserial primary key,
  title         text not null check (length(btrim(title)) between 1 and 80),
  subtitle      text check (subtitle is null or length(subtitle) <= 160),
  image_url     text not null,
  action_type   text not null default 'none'
                check (action_type in ('none', 'phone', 'whatsapp', 'url', 'place')),
  action_value  text check (action_value is null or length(action_value) <= 300),
  starts_on     date not null default current_date,
  ends_on       date not null default (current_date + 30),
  is_active     boolean not null default true,
  display_order int not null default 0,
  views         int not null default 0,
  clicks        int not null default 0,
  created_at    timestamptz not null default now(),
  check (ends_on >= starts_on)
);

alter table public.sponsored_slides enable row level security;

drop policy if exists read_live    on public.sponsored_slides;
drop policy if exists admin_insert on public.sponsored_slides;
drop policy if exists admin_update on public.sponsored_slides;
drop policy if exists admin_delete on public.sponsored_slides;

create policy read_live on public.sponsored_slides for select using (
  public.app_is_admin()
  or (is_active and current_date between starts_on and ends_on));
create policy admin_insert on public.sponsored_slides for insert with check (public.app_is_admin());
create policy admin_update on public.sponsored_slides for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.sponsored_slides for delete using (public.app_is_admin());

grant select, insert, update, delete on public.sponsored_slides to anon, authenticated;
grant usage, select on sequence public.sponsored_slides_id_seq to anon, authenticated;

-- p_kind: 'view' | 'click'
create or replace function public.app_sponsored_event(p_id bigint, p_kind text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.sponsored_slides
     set views  = views  + case when p_kind = 'view'  then 1 else 0 end,
         clicks = clicks + case when p_kind = 'click' then 1 else 0 end
   where id = p_id
     and is_active
     and current_date between starts_on and ends_on;
$$;

revoke all on function public.app_sponsored_event(bigint, text) from public;
grant execute on function public.app_sponsored_event(bigint, text) to anon, authenticated;

-- 🔙 ROLLBACK
-- drop function public.app_sponsored_event(bigint, text);
-- drop table public.sponsored_slides;
