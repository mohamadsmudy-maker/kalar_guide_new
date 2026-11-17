-- ═══════════════════════════════════════════════════════════════════
-- ⚡ Kalar Guide — push notification for breaking news
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261123_news_tickers.sql. Safe to run more than once.
--
-- news_tickers.notified_at: کاتی ناردنی ئاگاداری push. فەنکشنی
-- send-breaking-news تەنها بۆ هەواڵێک دەنێرێت کە null بێت و یەکسەر
-- پڕی دەکاتەوە، بۆیە هەر هەواڵێک تەنها یەکجار دەنێردرێت.
-- هەواڵە کۆنەکان وەک «نێردراو» نیشانە دەکرێن، تاکو گۆڕینیان ئاگاداری نەنێرێت.
-- ═══════════════════════════════════════════════════════════════════

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'news_tickers' and column_name = 'notified_at'
  ) then
    alter table public.news_tickers add column notified_at timestamptz;
    update public.news_tickers set notified_at = created_at;
  end if;
end $$;

-- 🔙 ROLLBACK
-- alter table public.news_tickers drop column notified_at;
