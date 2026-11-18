-- ═══════════════════════════════════════════════════════════════════
-- ⭐ Kalar Guide — featured (sponsored) places
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- dukan.featured_until = تا ئەو کاتە شوێنەکە «پێشنیارکراو»ـە (لە سەرەوەی
-- لیست + نیشانە). null یان ڕابردوو = ئاسایی. تەنها ئەدمین دەیگۆڕێت:
-- ڤێندەر دەتوانێت شوێنی خۆی دەستکاری بکات، بەڵام ئەم ستوونە نا.
-- کردنەوە/داخستنی هەموو تایبەتمەندییەکە: app_settings.features.featured_places
-- ═══════════════════════════════════════════════════════════════════

alter table public.dukan add column if not exists featured_until timestamptz;

create index if not exists dukan_featured_until_idx
  on public.dukan (featured_until) where featured_until is not null;

create or replace function public.dukan_guard_featured()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.app_is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.featured_until := null;
  elsif new.featured_until is distinct from old.featured_until then
    new.featured_until := old.featured_until;
  end if;
  return new;
end;
$$;

drop trigger if exists dukan_guard_featured on public.dukan;
create trigger dukan_guard_featured
  before insert or update on public.dukan
  for each row execute function public.dukan_guard_featured();

-- 🔙 ROLLBACK
-- drop trigger dukan_guard_featured on public.dukan;
-- drop function public.dukan_guard_featured();
-- alter table public.dukan drop column featured_until;
