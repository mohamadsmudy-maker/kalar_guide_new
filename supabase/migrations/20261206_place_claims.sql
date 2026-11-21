-- ═══════════════════════════════════════════════════════════════════
-- 🏪 Kalar Guide — «ئەم شوێنە هی منە» (place ownership claims)
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once.
--
-- بەکارهێنەرێکی چووەژوورەوە داوا دەکات ببێتە خاوەنی شوێنێک. ئەدمین
-- پەسەندی دەکات → بەکارهێنەرەکە دەبێتە vendor ـی ئەو شوێنە (app_users.store_id)
-- و دەتوانێت خۆی زانیاری، وێنە، کات و نرخەکان نوێ بکاتەوە (RLS ـی owner_update).
-- ئەدمین هەرگیز دانابەزێنرێت بۆ vendor.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.place_claims (
  id          bigserial primary key,
  store_id    text not null,
  user_id     text not null,
  note        text check (note is null or length(note) <= 500),
  status      text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at  timestamptz not null default now(),
  reviewed_at timestamptz
);

create unique index if not exists place_claims_one_pending
  on public.place_claims (store_id, user_id) where status = 'pending';
create index if not exists place_claims_status_idx
  on public.place_claims (status, created_at desc);

alter table public.place_claims enable row level security;

drop policy if exists read_own_or_admin on public.place_claims;
drop policy if exists admin_delete      on public.place_claims;
create policy read_own_or_admin on public.place_claims for select
  using (public.app_is_admin() or user_id = public.app_user_id());
create policy admin_delete on public.place_claims for delete using (public.app_is_admin());

grant select, delete on public.place_claims to anon, authenticated;

-- 'ok' | 'duplicate' | 'not_found' | 'login' | 'already_owner'
create or replace function public.app_claim_place(p_store_id text, p_note text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user text := public.app_user_id();
begin
  if v_user is null then
    return 'login';
  end if;
  if not exists (select 1 from public.dukan d where d.id::text = p_store_id) then
    return 'not_found';
  end if;
  if public.app_store_id() = p_store_id then
    return 'already_owner';
  end if;
  insert into public.place_claims (store_id, user_id, note)
  values (p_store_id, v_user, nullif(left(btrim(coalesce(p_note, '')), 500), ''))
  on conflict do nothing;
  if not found then
    return 'duplicate';
  end if;
  return 'ok';
end;
$$;

-- ئەدمین: پەسەند/ڕەتکردنەوە. 'ok' | 'forbidden' | 'not_found'
create or replace function public.app_review_claim(p_claim_id bigint, p_approve boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.place_claims;
begin
  if not public.app_is_admin() then
    return 'forbidden';
  end if;
  select * into c from public.place_claims where id = p_claim_id and status = 'pending';
  if not found then
    return 'not_found';
  end if;

  update public.place_claims
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_at = now()
   where id = p_claim_id;

  if p_approve then
    update public.app_users u
       set role = 'vendor', is_approved = true, store_id = c.store_id::bigint
     where u.id::text = c.user_id and u.role <> 'admin';
    -- داواکارییەکانی تری هەمان شوێن ڕەت دەکرێنەوە
    update public.place_claims
       set status = 'rejected', reviewed_at = now()
     where store_id = c.store_id and status = 'pending';
  end if;
  return 'ok';
end;
$$;

-- لیستی ئەدمین: داواکاری + ناوی شوێن + ناو و ژمارەی داواکەر
create or replace function public.app_pending_claims()
returns table (id bigint, store_id text, store_name text, user_name text, user_phone text, note text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.store_id, d.name::text, u.name::text, u.phone::text, c.note, c.created_at
    from public.place_claims c
    left join public.dukan d on d.id::text = c.store_id
    left join public.app_users u on u.id::text = c.user_id
   where c.status = 'pending' and public.app_is_admin()
   order by c.created_at;
$$;

revoke all on function public.app_claim_place(text, text)     from public;
revoke all on function public.app_review_claim(bigint, boolean) from public;
revoke all on function public.app_pending_claims()           from public;
grant execute on function public.app_claim_place(text, text)     to anon, authenticated;
grant execute on function public.app_review_claim(bigint, boolean) to anon, authenticated;
grant execute on function public.app_pending_claims()           to anon, authenticated;

-- Health check
select 'place_claims' as item, count(*) as rows from public.place_claims;
