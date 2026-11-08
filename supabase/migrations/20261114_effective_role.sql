-- ═══════════════════════════════════════════════════════════════════
-- 🔐 Kalar Guide — the app shows the role the server actually grants
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- app_current_user() returned app_users.role. For a vendor who is not
-- (or no longer) approved, the session is bound as 'customer', so the app
-- showed vendor screens whose saves were then refused. It now returns the
-- session's role and store (what RLS uses); approval status is unchanged.
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.app_current_user()
returns table (id text, name text, phone text, role text, is_approved boolean, store_id text)
language sql stable
security definer
set search_path = public
as $$
  select u.id::text, u.name::text, u.phone::text, s.role::text,
         coalesce(u.is_approved, false), s.store_id::text
    from public.app_sessions s
    join public.app_users u on u.id::text = s.user_id
   where s.auth_uid = auth.uid();
$$;
grant execute on function public.app_current_user() to anon, authenticated;
