-- ═══════════════════════════════════════════════════════════════════
-- 📣 Kalar Guide — tell the citizen when their complaint's status changes
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261126_complaint_push.sql. Safe to run more than once.
--
-- complaints.status_notified: دوایین دۆخ کە بۆ هاوڵاتییەکە نێردراوە.
-- send-complaint-notification تەنها کاتێک دەنێرێت کە status جیاواز بێت لەمە،
-- و یەکسەر نوێی دەکاتەوە، بۆیە هەر گۆڕانێک تەنها یەکجار دەنێردرێت.
-- سکاڵای نوێ: status_notified = status (هاوڵاتی بۆ «چاوەڕوان» ئاگاداری وەرناگرێت).
-- ═══════════════════════════════════════════════════════════════════

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'complaints' and column_name = 'status_notified'
  ) then
    alter table public.complaints add column status_notified text;
    update public.complaints set status_notified = status;
  end if;
end $$;

create or replace function public.app_complaint_status_seen()
returns trigger
language plpgsql
as $$
begin
  new.status_notified := new.status;
  return new;
end;
$$;

drop trigger if exists complaints_status_seen on public.complaints;
create trigger complaints_status_seen
  before insert on public.complaints
  for each row execute function public.app_complaint_status_seen();

-- 🔙 ROLLBACK
-- drop trigger complaints_status_seen on public.complaints;
-- drop function public.app_complaint_status_seen();
-- alter table public.complaints drop column status_notified;
