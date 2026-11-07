-- ═══════════════════════════════════════════════════════════════════
-- 🔐 Kalar Guide — RLS for per-user rows (likes, favorites, reviews…)
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql.
--
-- user_id in these tables holds EITHER the app user id (app_users.id)
-- OR the Supabase auth id, depending on which screen wrote it. app_is_owner()
-- accepts both, so no data migration is needed.
--
-- Not covered: active_users (rows are keyed by device_id, not by user).
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.app_is_owner(p_user_id text)
returns boolean
language sql stable
as $$
  select p_user_id is not null
     and (p_user_id = auth.uid()::text or p_user_id = public.app_user_id());
$$;
grant execute on function public.app_is_owner(text) to anon, authenticated;

do $$
declare
  t text;
  p record;
begin
  -- Private lists: only the owner (and the admin) can see or change them
  foreach t in array array['news_likes', 'news_favorites', 'favorite_stores', 'event_interests'] loop
    if to_regclass('public.' || t) is null then
      raise notice 'skip: table % does not exist', t;
      continue;
    end if;
    execute format('alter table public.%I enable row level security', t);
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy owner_all on public.%I for all
                      using (public.app_is_admin() or public.app_is_owner(user_id::text))
                      with check (public.app_is_owner(user_id::text))', t);
  end loop;

  -- Reviews: approved ones are public; authors manage their own; admin moderates
  if to_regclass('public.reviews') is not null then
    alter table public.reviews enable row level security;
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = 'reviews' loop
      execute format('drop policy %I on public.reviews', p.policyname);
    end loop;
    create policy read_reviews on public.reviews for select using (
      coalesce(is_approved, false)
      or public.app_is_owner(user_id::text)
      or public.app_is_admin());
    create policy write_own on public.reviews for insert
      with check (public.app_is_owner(user_id::text));
    create policy update_own on public.reviews for update
      using (public.app_is_owner(user_id::text) or public.app_is_admin())
      with check (public.app_is_owner(user_id::text) or public.app_is_admin());
    create policy delete_own on public.reviews for delete
      using (public.app_is_owner(user_id::text) or public.app_is_admin());
  end if;
end $$;

-- Triggers on reviews (e.g. updating dukan.average_rating) run as the
-- reviewer, who may not update dukan any more. Let them run as owner.
do $$
declare f regprocedure;
begin
  for f in
    select distinct tg.tgfoid::regprocedure
      from pg_trigger tg
     where tg.tgrelid = to_regclass('public.reviews') and not tg.tgisinternal
  loop
    execute format('alter function %s security definer set search_path = public', f);
  end loop;
end $$;

-- 🔙 ROLLBACK
-- alter table public.news_likes      disable row level security;
-- alter table public.news_favorites  disable row level security;
-- alter table public.favorite_stores disable row level security;
-- alter table public.event_interests disable row level security;
-- alter table public.reviews         disable row level security;
