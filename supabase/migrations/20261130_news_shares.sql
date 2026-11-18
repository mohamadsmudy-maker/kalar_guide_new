-- ═══════════════════════════════════════════════════════════════════
-- 📤 Kalar Guide — share counter for news
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- هەر جارێک کە کەسێک هەواڵێک شێر دەکات، increment_news_shares ژمارەکە
-- زیاد دەکات و ژمارە نوێیەکە دەگەڕێنێتەوە. RLS نووسینی ڕاستەوخۆ قەدەغە
-- دەکات، بۆیە ئەم فەنکشنە security definer ـە و تەنها ئەم ستوونە دەگۆڕێت.
-- ═══════════════════════════════════════════════════════════════════

alter table public.news add column if not exists shares integer not null default 0;

create or replace function public.increment_news_shares(p_news_id text)
returns integer
language sql
security definer
set search_path = public
as $$
  update public.news
     set shares = coalesce(shares, 0) + 1
   where id::text = p_news_id
  returning shares;
$$;

revoke all on function public.increment_news_shares(text) from public;
grant execute on function public.increment_news_shares(text) to anon, authenticated;
