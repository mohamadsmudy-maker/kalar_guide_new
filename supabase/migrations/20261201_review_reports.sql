-- ═══════════════════════════════════════════════════════════════════
-- 🚩 Kalar Guide — reporting reviews (Google Play UGC policy)
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- هەر کەسێک (میوانیش) دەتوانێت هەڵسەنگاندنێک ڕاپۆرت بکات بە
-- app_report_review(). هەر کەسە تەنها یەکجار بۆ هەر هەڵسەنگاندنێک.
-- کاتێک ٣ کەسی جیاواز ڕاپۆرتیان کرد، هەڵسەنگاندنەکە خۆکار دەشاردرێتەوە
-- (is_approved = false) تا ئەدمین بڕیار دەدات. تەنها ئەدمین ڕاپۆرتەکان دەبینێت.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.review_reports (
  id          bigserial primary key,
  review_id   text not null,
  store_id    bigint,
  reason      text not null check (reason in ('spam', 'offensive', 'false', 'personal', 'other')),
  note        text check (note is null or length(note) <= 500),
  reporter    text not null,
  status      text not null default 'open' check (status in ('open', 'dismissed', 'removed')),
  created_at  timestamptz not null default now(),
  unique (review_id, reporter)
);

create index if not exists review_reports_open_idx
  on public.review_reports (status, created_at desc);

alter table public.review_reports enable row level security;

drop policy if exists admin_read   on public.review_reports;
drop policy if exists admin_update on public.review_reports;
drop policy if exists admin_delete on public.review_reports;

create policy admin_read   on public.review_reports for select using (public.app_is_admin());
create policy admin_update on public.review_reports for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.review_reports for delete using (public.app_is_admin());

grant select, update, delete on public.review_reports to anon, authenticated;

-- 'ok' | 'duplicate' | 'not_found' | 'invalid'
create or replace function public.app_report_review(
  p_review_id text,
  p_reason    text,
  p_note      text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter text := coalesce(public.app_user_id(), auth.uid()::text);
  v_store    bigint;
  v_count    int;
begin
  if v_reporter is null or p_reason not in ('spam', 'offensive', 'false', 'personal', 'other') then
    return 'invalid';
  end if;

  select r.store_id into v_store from public.reviews r where r.id::text = p_review_id;
  if not found then
    return 'not_found';
  end if;

  insert into public.review_reports (review_id, store_id, reason, note, reporter)
  values (p_review_id, v_store, p_reason, nullif(left(btrim(coalesce(p_note, '')), 500), ''), v_reporter)
  on conflict (review_id, reporter) do nothing;
  if not found then
    return 'duplicate';
  end if;

  select count(*) into v_count
    from public.review_reports
   where review_id = p_review_id and status = 'open';
  if v_count >= 3 then
    update public.reviews set is_approved = false where id::text = p_review_id;
  end if;
  return 'ok';
end;
$$;

revoke all on function public.app_report_review(text, text, text) from public;
grant execute on function public.app_report_review(text, text, text) to anon, authenticated;

-- 🔙 ROLLBACK
-- drop function public.app_report_review(text, text, text);
-- drop table public.review_reports;
