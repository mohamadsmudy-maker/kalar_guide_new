-- ═══════════════════════════════════════════════════════════════════
-- 📣 Kalar Guide — push notification to admins for new complaints
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- complaints.notified_at: کاتی ناردنی ئاگاداری بۆ ئەدمینەکان. فەنکشنی
-- send-complaint-notification تەنها بۆ سکاڵایەک دەنێرێت کە null بێت و یەکسەر
-- پڕی دەکاتەوە، بۆیە هەر سکاڵایەک تەنها یەکجار دەنێردرێت.
-- سکاڵا کۆنەکان وەک «نێردراو» نیشانە دەکرێن.
-- ═══════════════════════════════════════════════════════════════════

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'complaints' and column_name = 'notified_at'
  ) then
    alter table public.complaints add column notified_at timestamptz;
    update public.complaints set notified_at = now();
  end if;
end $$;

-- 🔙 ROLLBACK
-- alter table public.complaints drop column notified_at;
