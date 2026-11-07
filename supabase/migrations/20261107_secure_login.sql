-- ═══════════════════════════════════════════════════════════════════
-- 🔐 Kalar Guide — server-side login (run BEFORE releasing the new app)
-- ═══════════════════════════════════════════════════════════════════
-- Moves password checking and vendor-code checking from the phone to the
-- database. After this, password hashes and vendor codes never leave the
-- server.
--
-- Supabase Dashboard → SQL Editor → paste this whole file → Run.
--
-- Assumed columns (adjust names if yours differ):
--   app_users(id, name, phone, password, role, is_approved, store_id, created_at)
--   dukan(id, name, phone, category, vendor_code)
--
-- Legacy SHA-256 hashes: if old users were hashed with PASSWORD_SALT, set it
-- once (it is then readable only by the database, not by the app):
--   ALTER DATABASE postgres SET app.password_salt = 'YOUR_OLD_SALT';
-- ═══════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto with schema extensions;

-- ───────────────────────────────────────────────────────────────────
-- 1) Login: returns the user WITHOUT the password, or no rows.
--    Old plaintext / SHA-256 passwords are upgraded to bcrypt on login.
-- ───────────────────────────────────────────────────────────────────
create or replace function public.app_login(p_phone text, p_password text)
returns table (id text, name text, phone text, role text, is_approved boolean, store_id text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  u    public.app_users%rowtype;
  ok   boolean := false;
  salt text := coalesce(current_setting('app.password_salt', true), '');
begin
  if p_phone is null or p_password is null or length(p_password) = 0 then
    return;
  end if;

  select * into u from public.app_users a where a.phone = p_phone limit 1;
  if not found or u.password is null or u.password = '' then
    perform pg_sleep(0.3);           -- slow down phone-number guessing
    return;
  end if;

  if u.password like '$2%' and length(u.password) = 60 then
    ok := extensions.crypt(p_password, u.password) = u.password;
  elsif length(u.password) = 64 and salt <> '' then
    ok := encode(extensions.digest(salt || p_password || salt, 'sha256'), 'hex') = u.password;
  else
    ok := u.password = p_password;   -- legacy plaintext
  end if;

  if not ok then
    perform pg_sleep(0.3);
    return;
  end if;

  -- upgrade legacy hashes to bcrypt
  if not (u.password like '$2%' and length(u.password) = 60) then
    update public.app_users
       set password = extensions.crypt(p_password, extensions.gen_salt('bf', 12))
     where app_users.id = u.id;
  end if;

  return query select u.id::text, u.name::text, u.phone::text, u.role::text,
                      coalesce(u.is_approved, false), u.store_id::text;
end;
$$;

-- ───────────────────────────────────────────────────────────────────
-- 2) Customer sign-up  →  'ok' | 'phone_exists' | 'invalid'
--    The role is fixed to 'customer' here; the app can no longer choose it.
-- ───────────────────────────────────────────────────────────────────
create or replace function public.app_register_customer(p_name text, p_phone text, p_password text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if coalesce(trim(p_name), '') = '' or length(coalesce(p_phone, '')) < 10
     or length(coalesce(p_password, '')) < 8 then
    return 'invalid';
  end if;
  if exists (select 1 from public.app_users where phone = p_phone) then
    return 'phone_exists';
  end if;

  insert into public.app_users (name, phone, password, role, is_approved)
  values (trim(p_name), p_phone,
          extensions.crypt(p_password, extensions.gen_salt('bf', 12)),
          'customer', true);
  return 'ok';
end;
$$;

-- ───────────────────────────────────────────────────────────────────
-- 3) Vendor request (needs the store's vendor_code)
--    → 'ok' | 'phone_exists' | 'bad_code' | 'invalid'
-- ───────────────────────────────────────────────────────────────────
create or replace function public.app_request_vendor(
  p_phone text, p_password text, p_store_id text, p_vendor_code text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  s public.dukan%rowtype;
begin
  if length(coalesce(p_phone, '')) < 10 or length(coalesce(p_password, '')) < 8 then
    return 'invalid';
  end if;

  select * into s from public.dukan d where d.id::text = p_store_id limit 1;
  if not found or coalesce(trim(s.vendor_code), '') = ''
     or trim(s.vendor_code) <> trim(coalesce(p_vendor_code, '')) then
    perform pg_sleep(0.3);
    return 'bad_code';
  end if;

  if exists (select 1 from public.app_users where phone = p_phone) then
    return 'phone_exists';
  end if;

  insert into public.app_users (name, phone, password, role, is_approved, store_id, created_at)
  values (s.name, p_phone,
          extensions.crypt(p_password, extensions.gen_salt('bf', 12)),
          'vendor_pending', false, s.id, now());
  return 'ok';
end;
$$;

-- ───────────────────────────────────────────────────────────────────
-- 4) Vendor-code check for the sign-up form (true / false only)
-- ───────────────────────────────────────────────────────────────────
create or replace function public.verify_vendor_code(p_store_id text, p_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  ok boolean;
begin
  select coalesce(trim(d.vendor_code), '') <> ''
         and trim(d.vendor_code) = trim(coalesce(p_code, ''))
    into ok
    from public.dukan d where d.id::text = p_store_id;
  if not coalesce(ok, false) then
    perform pg_sleep(0.3);
  end if;
  return coalesce(ok, false);
end;
$$;

-- p_store_id is text so it works whether dukan.id is int, bigint or uuid.

grant execute on function public.app_login(text, text)                         to anon, authenticated;
grant execute on function public.app_register_customer(text, text, text)       to anon, authenticated;
grant execute on function public.app_request_vendor(text, text, text, text)    to anon, authenticated;
grant execute on function public.verify_vendor_code(text, text)                to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 5) Lock down the secret columns  (do this AFTER the new app is live)
-- ═══════════════════════════════════════════════════════════════════
-- Old app versions read app_users.password and dukan.vendor_code directly.
-- Once everyone has updated, uncomment these lines so nobody can read them:
--
-- revoke select (password)    on public.app_users from anon, authenticated;
-- revoke select (vendor_code) on public.dukan     from anon, authenticated;
-- revoke insert, update, delete on public.app_users from anon;
--
-- Note: column-level revoke only works if table-level SELECT is not granted.
-- If it is, do instead:
--   revoke select on public.app_users from anon, authenticated;
--   grant  select (id, name, phone, role, is_approved, store_id, created_at)
--          on public.app_users to anon, authenticated;
-- (and the same pattern for dukan without vendor_code)
--
-- Also check that get_user_for_login does NOT return the password column.
