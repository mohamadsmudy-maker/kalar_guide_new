-- ═══════════════════════════════════════════════════════════════════
-- 🔐 Kalar Guide — sign in with Google + delete account
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- Customers sign in with Google (free; the e-mail is verified by Google,
-- so no paid SMS check of the phone number is needed). The app calls
-- supabase.auth.signInWithIdToken(google) and then app_login_google(),
-- which finds or creates the app_users row and binds the session exactly
-- like app_login() does. Vendors and the admin keep phone + password;
-- if the admin writes a Google e-mail into their app_users.email, that
-- Google account signs in with the same role.
--
-- app_delete_account(): Google Play requires in-app account deletion.
-- ═══════════════════════════════════════════════════════════════════

alter table public.app_users add column if not exists email text;
create unique index if not exists app_users_email_key
  on public.app_users (lower(email)) where email is not null;

-- Google users have no phone number or password
do $$ begin
  alter table public.app_users alter column phone drop not null;
exception when others then raise notice 'phone: %', sqlerrm;
end $$;
do $$ begin
  alter table public.app_users alter column password drop not null;
exception when others then raise notice 'password: %', sqlerrm;
end $$;

drop function if exists public.app_login_google(text);
create function public.app_login_google(p_name text default null)
returns table (id text, name text, phone text, role text, is_approved boolean, store_id text, email text)
language plpgsql
security definer
set search_path = public
as $$
declare
  claims  jsonb := coalesce(auth.jwt(), '{}'::jsonb);
  v_email text  := lower(nullif(btrim(claims ->> 'email'), ''));
  v_name  text;
  u       public.app_users%rowtype;
begin
  -- only a real (not anonymous) Google session with an e-mail
  if auth.uid() is null
     or v_email is null
     or coalesce((claims ->> 'is_anonymous')::boolean, false)
     or not (coalesce(claims -> 'app_metadata' ->> 'provider', '') = 'google'
              or coalesce(claims -> 'app_metadata' -> 'providers', '[]'::jsonb) ? 'google') then
    return;
  end if;

  select * into u from public.app_users a where lower(a.email) = v_email limit 1;

  if not found then
    v_name := coalesce(
      nullif(btrim(p_name), ''),
      nullif(btrim(claims -> 'user_metadata' ->> 'full_name'), ''),
      nullif(btrim(claims -> 'user_metadata' ->> 'name'), ''),
      split_part(v_email, '@', 1));
    insert into public.app_users (name, email, role, is_approved)
    values (left(v_name, 80), v_email, 'customer', true)
    returning * into u;
  end if;

  insert into public.app_sessions (auth_uid, user_id, phone, role, store_id)
  values (auth.uid(), u.id::text, u.phone::text,
          case when u.role in ('vendor', 'department') and not coalesce(u.is_approved, false)
               then 'customer'
               when u.role = 'vendor_pending' then 'customer'
               else coalesce(u.role, 'customer') end,
          u.store_id::text)
  on conflict (auth_uid) do update
    set user_id = excluded.user_id, phone = excluded.phone, role = excluded.role,
        store_id = excluded.store_id, created_at = now();

  return query select u.id::text, u.name::text, u.phone::text, u.role::text,
                      coalesce(u.is_approved, false), u.store_id::text, u.email::text;
end;
$$;
grant execute on function public.app_login_google(text) to authenticated;

-- Deletes the signed-in user's account and personal rows.
-- The admin account cannot delete itself (so the app is never left without one).
create or replace function public.app_delete_account()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user text := public.app_user_id();
  v_auth text := auth.uid()::text;
  t text;
begin
  if v_user is null then return 'not_logged_in'; end if;
  if public.app_role() = 'admin' then return 'admin_forbidden'; end if;

  foreach t in array array['favorite_stores', 'news_likes', 'news_favorites', 'event_interests', 'reviews'] loop
    if to_regclass('public.' || t) is not null then
      execute format('delete from public.%I where user_id::text = $1 or user_id::text = $2', t)
        using v_user, v_auth;
    end if;
  end loop;

  delete from public.app_sessions where user_id = v_user;
  delete from public.app_users where id::text = v_user;

  -- the Google / Supabase login itself
  if to_regclass('auth.users') is not null and v_auth is not null then
    execute 'delete from auth.users where id = $1::uuid' using v_auth;
  end if;
  return 'ok';
end;
$$;
grant execute on function public.app_delete_account() to authenticated;

-- 🔙 ROLLBACK
-- drop function public.app_delete_account();
-- drop function public.app_login_google(text);
-- drop index public.app_users_email_key;
-- alter table public.app_users drop column email;
