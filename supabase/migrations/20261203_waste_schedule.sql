-- ═══════════════════════════════════════════════════════════════════
-- 🗑️ Kalar Guide — garbage collection days per neighborhood
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- هەر گەڕەکێک یەک ڕیز: ئەو ڕۆژانەی ئۆتۆمبێلی خۆڵ دێت (weekdays:
-- 1 = دووشەممە ... 6 = شەممە، 7 = یەکشەممە، وەک Dart)، کات و تێبینی.
-- هەمووان دەیخوێننەوە؛ تەنها ئەدمین دەیگۆڕێت. ئاگادارکردنەوەی «شەوی پێشتر»
-- لەسەر مۆبایلەکە خۆی ڕێک دەخرێت.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.waste_schedule (
  neighborhood_id   bigint primary key,
  neighborhood_name text,
  weekdays          smallint[] not null default '{}'
                    check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  time_text         text check (time_text is null or length(time_text) <= 40),
  note              text check (note is null or length(note) <= 300),
  updated_at        timestamptz not null default now()
);

alter table public.waste_schedule enable row level security;

drop policy if exists read_all     on public.waste_schedule;
drop policy if exists admin_insert on public.waste_schedule;
drop policy if exists admin_update on public.waste_schedule;
drop policy if exists admin_delete on public.waste_schedule;

create policy read_all     on public.waste_schedule for select using (true);
create policy admin_insert on public.waste_schedule for insert with check (public.app_is_admin());
create policy admin_update on public.waste_schedule for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.waste_schedule for delete using (public.app_is_admin());

grant select on public.waste_schedule to anon, authenticated;
grant insert, update, delete on public.waste_schedule to anon, authenticated;

-- 🔙 ROLLBACK
-- drop table public.waste_schedule;
