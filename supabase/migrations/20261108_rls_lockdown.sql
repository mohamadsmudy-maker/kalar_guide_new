-- ═══════════════════════════════════════════════════════════════════
-- 🔐 Kalar Guide — Row Level Security (server-side roles)
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261107_secure_login.sql, and release the matching app build
-- at the same time (old builds keep reading, but admin/vendor writes from
-- old builds stop working until the user logs in again on the new build).
--
-- Problem this solves:
--   The app decided "is this user an admin?" on the phone only. Anyone with
--   the anon key (it ships inside the APK) could write to any table directly.
--
-- How it works:
--   Every app install is signed in to Supabase anonymously, so each request
--   carries a stable auth.uid(). When app_login succeeds, the server records
--   (auth.uid() → app user, role, store_id) in app_sessions. RLS policies
--   then ask app_sessions — not the phone — what the caller may do.
--
-- ⚠️ BEFORE RUNNING
--   1. Back up: Dashboard → Database → Backups (or pg_dump).
--   2. See what policies exist today:
--        select tablename, policyname, cmd, roles, qual, with_check
--          from pg_policies where schemaname = 'public' order by 1, 2;
--      Step 4 below DROPS existing policies on the tables it manages,
--      because any old "allow all" policy would cancel the new rules.
--   3. Admins, vendors and department managers must log in again once after
--      updating the app (their old session has no server-side record).
--
-- Rollback is at the bottom of this file.
-- ═══════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────
-- 1) Server-side session table
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.app_sessions (
  auth_uid   uuid primary key,
  user_id    text not null,
  phone      text,
  role       text not null,
  store_id   text,
  created_at timestamptz not null default now()
);

alter table public.app_sessions enable row level security;
-- No policies: only security-definer functions below can touch it.
revoke all on public.app_sessions from anon, authenticated;


-- ───────────────────────────────────────────────────────────────────
-- 2) Role helpers used by the policies
-- ───────────────────────────────────────────────────────────────────
create or replace function public.app_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select coalesce(
    (select s.role from public.app_sessions s where s.auth_uid = auth.uid()),
    'guest');
$$;

create or replace function public.app_store_id()
returns text
language sql stable security definer
set search_path = public
as $$
  select s.store_id from public.app_sessions s where s.auth_uid = auth.uid();
$$;

create or replace function public.app_user_id()
returns text
language sql stable security definer
set search_path = public
as $$
  select s.user_id from public.app_sessions s where s.auth_uid = auth.uid();
$$;

create or replace function public.app_phone()
returns text
language sql stable security definer
set search_path = public
as $$
  select s.phone from public.app_sessions s where s.auth_uid = auth.uid();
$$;

-- department managers are linked to their department by departments.user_phone
create or replace function public.app_owns_department(p_department_id text)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.app_role() = 'admin'
      or (public.app_role() = 'department'
          and exists (select 1 from public.departments d
                       where d.id::text = p_department_id
                         and d.user_phone is not null
                         and d.user_phone = public.app_phone()));
$$;

create or replace function public.app_is_admin()
returns boolean
language sql stable
as $$ select public.app_role() = 'admin'; $$;

-- true when the caller is admin, or the vendor/department that owns p_store_id
create or replace function public.app_owns(p_store_id text, p_role text)
returns boolean
language sql stable
as $$
  select public.app_role() = 'admin'
      or (public.app_role() = p_role
          and p_store_id is not null
          and public.app_store_id() = p_store_id);
$$;

grant execute on function public.app_role()            to anon, authenticated;
grant execute on function public.app_store_id()        to anon, authenticated;
grant execute on function public.app_user_id()         to anon, authenticated;
grant execute on function public.app_is_admin()        to anon, authenticated;
grant execute on function public.app_owns(text, text)  to anon, authenticated;
grant execute on function public.app_phone()           to anon, authenticated;
grant execute on function public.app_owns_department(text) to anon, authenticated;


-- ───────────────────────────────────────────────────────────────────
-- 3) Login now binds the session; plus current-user / logout / FCM RPCs
-- ───────────────────────────────────────────────────────────────────
-- Same body as 20261107_secure_login.sql, with the session binding added.
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
    perform pg_sleep(0.3);
    return;
  end if;

  if u.password like '$2%' and length(u.password) = 60 then
    ok := extensions.crypt(p_password, u.password) = u.password;
  elsif length(u.password) = 64 and salt <> '' then
    ok := encode(extensions.digest(salt || p_password || salt, 'sha256'), 'hex') = u.password;
  else
    ok := u.password = p_password;
  end if;

  if not ok then
    perform pg_sleep(0.3);
    return;
  end if;

  if not (u.password like '$2%' and length(u.password) = 60) then
    update public.app_users
       set password = extensions.crypt(p_password, extensions.gen_salt('bf', 12))
     where app_users.id = u.id;
  end if;

  -- 🔐 bind this device's Supabase session to the user.
  -- Unapproved vendors are bound as plain customers.
  if auth.uid() is not null then
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
  end if;

  return query select u.id::text, u.name::text, u.phone::text, u.role::text,
                      coalesce(u.is_approved, false), u.store_id::text;
end;
$$;

-- Restores the profile on app start. Replaces get_user_for_login(phone),
-- which trusted whatever phone number was stored on the device.
create or replace function public.app_current_user()
returns table (id text, name text, phone text, role text, is_approved boolean, store_id text)
language sql stable
security definer
set search_path = public
as $$
  select u.id::text, u.name::text, u.phone::text, u.role::text,
         coalesce(u.is_approved, false), u.store_id::text
    from public.app_sessions s
    join public.app_users u on u.id::text = s.user_id
   where s.auth_uid = auth.uid();
$$;

create or replace function public.app_logout()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.app_sessions where auth_uid = auth.uid();
$$;

create or replace function public.app_set_fcm_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.app_users set fcm_token = p_token
   where id::text = public.app_user_id();
$$;

-- Keep sessions in sync when the admin approves / changes / deletes a user.
create or replace function public.app_sessions_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.app_sessions where user_id = old.id::text;
    return old;
  end if;
  update public.app_sessions
     set role = case when new.role in ('vendor', 'department') and not coalesce(new.is_approved, false)
                     then 'customer'
                     when new.role = 'vendor_pending' then 'customer'
                     else coalesce(new.role, 'customer') end,
         store_id = new.store_id::text,
         phone    = new.phone::text
   where user_id = new.id::text;
  return new;
end;
$$;

drop trigger if exists app_sessions_sync on public.app_users;
create trigger app_sessions_sync
  after update of role, is_approved, store_id, phone or delete on public.app_users
  for each row execute function public.app_sessions_sync();

grant execute on function public.app_login(text, text)     to anon, authenticated;
grant execute on function public.app_current_user()        to anon, authenticated;
grant execute on function public.app_logout()              to anon, authenticated;
grant execute on function public.app_set_fcm_token(text)   to anon, authenticated;

-- Counter RPCs the app already calls (increment_views, increment_likes, …)
-- must keep working for everyone after RLS blocks direct UPDATEs.
create or replace function public.increment_event_views(p_event_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.events set views = coalesce(views, 0) + 1 where id::text = p_event_id;
$$;
grant execute on function public.increment_event_views(text) to anon, authenticated;

do $$
declare f regprocedure;
begin
  for f in
    select p.oid::regprocedure from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('increment_views', 'increment_likes', 'decrement_likes',
                         'increment_gallery_view', 'get_presence_stats',
                         'get_neighborhood_by_location')
  loop
    execute format('alter function %s security definer set search_path = public', f);
  end loop;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- 4) Policies
-- ───────────────────────────────────────────────────────────────────
-- Helper: enable RLS on a table (if it exists) and drop its old policies.
create or replace function pg_temp.reset_rls(t text)
returns boolean
language plpgsql
as $$
declare p record;
begin
  if to_regclass('public.' || t) is null then
    raise notice 'skip: table % does not exist', t;
    return false;
  end if;
  execute format('alter table public.%I enable row level security', t);
  for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
    execute format('drop policy %I on public.%I', p.policyname, t);
  end loop;
  return true;
end;
$$;

do $$
declare t text;
begin
  -- 4a) Public content: everyone reads, only admin writes
  foreach t in array array[
    'main_categories', 'sub_categories', 'neighborhoods', 'banners', 'videos',
    'weather', 'emergency_services', 'complaint_instructions', 'events',
    'notifications'
  ] loop
    if pg_temp.reset_rls(t) then
      execute format('create policy read_all on public.%I for select using (true)', t);
      execute format('create policy admin_write on public.%I for all
                        using (public.app_is_admin()) with check (public.app_is_admin())', t);
    end if;
  end loop;

  -- 4b) Stores (dukan): admin creates/deletes, the owning vendor may edit its row
  --     (fuel / currency prices are stored on dukan)
  if pg_temp.reset_rls('dukan') then
    create policy read_all     on public.dukan for select using (true);
    create policy admin_insert on public.dukan for insert with check (public.app_is_admin());
    create policy admin_delete on public.dukan for delete using (public.app_is_admin());
    create policy owner_update on public.dukan for update
      using (public.app_owns(id::text, 'vendor'))
      with check (public.app_owns(id::text, 'vendor'));
  end if;

  -- 4c) Per-store rows: admin, or the vendor of that store
  foreach t in array array['news', 'store_services', 'products'] loop
    if pg_temp.reset_rls(t) then
      execute format('create policy read_all on public.%I for select using (true)', t);
      execute format('create policy owner_write on public.%I for all
                        using (public.app_owns(store_id::text, ''vendor''))
                        with check (public.app_owns(store_id::text, ''vendor''))', t);
    end if;
  end loop;

  foreach t in array array['currency_price_history', 'fuel_price_history'] loop
    if pg_temp.reset_rls(t) then
      execute format('create policy read_all on public.%I for select using (true)', t);
      execute format('create policy owner_insert on public.%I for insert
                        with check (public.app_owns(station_id::text, ''vendor''))', t);
      execute format('create policy admin_change on public.%I for update
                        using (public.app_is_admin()) with check (public.app_is_admin())', t);
      execute format('create policy admin_delete on public.%I for delete
                        using (public.app_is_admin())', t);
    end if;
  end loop;

  -- 4d) Departments: admin creates/deletes, the department manager edits its own
  if pg_temp.reset_rls('departments') then
    create policy read_all     on public.departments for select using (true);
    create policy admin_insert on public.departments for insert with check (public.app_is_admin());
    create policy admin_delete on public.departments for delete using (public.app_is_admin());
    create policy owner_update on public.departments for update
      using (public.app_owns_department(id::text))
      with check (public.app_is_admin()
                  or (public.app_role() = 'department' and user_phone = public.app_phone()));
  end if;

  if pg_temp.reset_rls('department_services') then
    create policy read_all on public.department_services for select using (true);
    create policy owner_write on public.department_services for all
      using (public.app_owns_department(department_id::text))
      with check (public.app_owns_department(department_id::text));
  end if;

  -- 4e) Complaints: anyone with a session can submit; only the sender and
  --     the admin can read; only the admin can change or delete.
  if pg_temp.reset_rls('complaints') then
    create policy submit on public.complaints for insert with check (true);
    create policy read_own_or_admin on public.complaints for select using (
      public.app_is_admin()
      or user_id::text = auth.uid()::text
      or user_id::text = public.app_user_id());
    create policy admin_update on public.complaints for update
      using (public.app_is_admin()) with check (public.app_is_admin());
    create policy admin_delete on public.complaints for delete using (public.app_is_admin());
  end if;

  -- 4f) Users: no direct access except for the admin.
  --     Login / sign-up / FCM token go through security-definer RPCs.
  if pg_temp.reset_rls('app_users') then
    create policy admin_read   on public.app_users for select using (public.app_is_admin());
    create policy admin_update on public.app_users for update
      using (public.app_is_admin()) with check (public.app_is_admin());
    create policy admin_delete on public.app_users for delete using (public.app_is_admin());
  end if;
end $$;

-- Not changed here (behave as before): reviews, store_ratings, news_likes,
-- news_favorites, favorite_stores, event_interests, active_users, storage.
-- Their user_id column mixes app user ids and auth ids, so ownership rules
-- need a data cleanup first.


-- ═══════════════════════════════════════════════════════════════════
-- 🔙 ROLLBACK (only if something breaks — re-opens the old hole)
-- ═══════════════════════════════════════════════════════════════════
-- do $$
-- declare t text;
-- begin
--   foreach t in array array['main_categories','sub_categories','neighborhoods',
--     'banners','videos','weather','emergency_services','complaint_instructions',
--     'events','notifications','dukan','news','store_services','products',
--     'currency_price_history','fuel_price_history','departments',
--     'department_services','complaints','app_users'] loop
--     if to_regclass('public.' || t) is not null then
--       execute format('alter table public.%I disable row level security', t);
--     end if;
--   end loop;
-- end $$;
