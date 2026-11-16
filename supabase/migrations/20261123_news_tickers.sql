-- ═══════════════════════════════════════════════════════════════════
-- 📺 Kalar Guide — Breaking News Ticker (news_tickers)
-- ═══════════════════════════════════════════════════════════════════
-- جەدوەلی توڵی هەواڵی بەپەلە: ئەدمین تێکستی چوار زمان دەنووسێت،
-- ئەپەکە چالاکەکانی پیشاندەدات وەک توڵی موشتەمەلی کۆتاییدا.
-- Safe to run more than once (CREATE TABLE IF NOT EXISTS, idempotent policies).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.news_tickers (
  id              serial       primary key,
  text_ku         text         not null default '',
  text_ar         text         not null default '',
  text_en         text         not null default '',
  text_fa         text         not null default '',
  is_active       boolean      not null default true,
  display_order   integer      not null default 0,
  created_at      timestamptz  not null default now()
);

alter table public.news_tickers enable row level security;

-- هەموو کەسێک تووڵە چالاکەکان دەبینێت
drop policy if exists "read active tickers" on public.news_tickers;
create policy "read active tickers"
  on public.news_tickers for select
  using (is_active = true);

-- تەنها ئەدمین دەتوانێت بنووسێت / بگۆڕێت / بسڕێتەوە
drop policy if exists "admin manage tickers" on public.news_tickers;
create policy "admin manage tickers"
  on public.news_tickers for all
  using  (public.app_role() = 'admin')
  with check (public.app_role() = 'admin');
