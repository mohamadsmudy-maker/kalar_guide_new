-- RLS behaviour tests. Run after 00_mock_supabase.sql and the migrations.
-- Any failed check raises an exception, so psql -v ON_ERROR_STOP=1 exits non-zero.
\set ON_ERROR_STOP 1

create schema t;
grant usage on schema t to anon, authenticated;

-- number of rows the statement touched; -1 if RLS rejected it
create function t.rows(stmt text) returns int language plpgsql as $$
declare n int;
begin
  execute stmt;
  get diagnostics n = row_count;
  return n;
exception
  when insufficient_privilege then return -1;
  when check_violation then return -2;
end $$;

create function t.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not coalesce(ok, false) then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;

create function t.as_user(uid text) returns void language sql as $$
  select set_config('test.uid', uid, false);
$$;

grant execute on all functions in schema t to anon, authenticated;

-- seed
insert into dukan(id, name, vendor_code) values (1, 'A', '111'), (2, 'B', '222');
insert into app_users(name, phone, password, role, is_approved, store_id) values
  ('admin', '07500000001', 'adminpass', 'admin', true, null),
  ('vend',  '07500000002', 'vendpass1', 'vendor', true, 1),
  ('dept',  '07500000003', 'deptpass1', 'department', true, null),
  ('cust',  '07500000004', 'custpass1', 'customer', true, null);
insert into departments(id, name_ku, user_phone) values (1, 'D1', '07500000003'), (2, 'D2', 'other');
insert into news(title, store_id) values ('n1', 1), ('n2', 2);
insert into events(id, title) values (1, 'e1');
insert into complaints(user_id) values ('someone-else');

set role authenticated;

-- ── guest ────────────────────────────────────────────────────────
select t.as_user('00000000-0000-0000-0000-00000000000a');
select t.check(app_role() = 'guest', 'guest has no role');
select t.check(t.rows($$update dukan set name = 'x'$$) = 0, 'guest cannot edit stores');
select t.check(t.rows($$insert into banners(title) values ('x')$$) = -1, 'guest cannot add banners');
select t.check(t.rows($$update app_users set role = 'admin'$$) = 0, 'guest cannot promote users');
select t.check((select count(*) from app_users) = 0, 'guest cannot read users');
select t.check((select count(*) from complaints) = 0, 'guest cannot read others complaints');
select t.check(t.rows($$insert into complaints(user_id) values ('00000000-0000-0000-0000-00000000000a')$$) = 1,
               'guest can submit a complaint');
select t.check((select count(*) from complaints) = 1, 'guest sees own complaint');
select increment_views(id) from news where title = 'n1';
select t.check((select views from news where title = 'n1') = 1, 'view counter works through RPC');
select increment_event_views('1');
select t.check((select views from events where id = 1) = 1, 'event view counter works');
select t.check(not exists (select 1 from app_current_user()), 'no session -> no profile');

-- ── customer ─────────────────────────────────────────────────────
select t.check(not exists (select 1 from app_login('07500000004', 'wrong')), 'wrong password rejected');
select t.check((select role from app_login('07500000004', 'custpass1')) = 'customer', 'customer login');
select t.check(app_role() = 'customer', 'session bound as customer');
select t.check(t.rows($$insert into banners(title) values ('x')$$) = -1, 'customer cannot add banners');

-- ── vendor (store 1) ─────────────────────────────────────────────
select t.as_user('00000000-0000-0000-0000-00000000000b');
select app_login('07500000002', 'vendpass1');
select t.check(app_role() = 'vendor' and app_store_id() = '1', 'vendor bound to store 1');
select t.check(t.rows($$update dukan set fuel_prices = '{}' where id = 1$$) = 1, 'vendor edits own store');
select t.check(t.rows($$update dukan set fuel_prices = '{}' where id = 2$$) = 0, 'vendor cannot edit other store');
select t.check(t.rows($$insert into news(title, store_id) values ('v', 1)$$) = 1, 'vendor posts news for own store');
select t.check(t.rows($$insert into news(title, store_id) values ('v', 2)$$) = -1, 'vendor cannot post for other store');
select t.check(t.rows($$insert into fuel_price_history(station_id, price) values (1, 1)$$) = 1, 'vendor adds own price history');
select t.check(t.rows($$insert into fuel_price_history(station_id, price) values (2, 1)$$) = -1, 'vendor cannot add other price history');
select t.check(t.rows($$delete from dukan where id = 1$$) = 0, 'vendor cannot delete stores');
select app_set_fcm_token('tok');

-- ── department (department 1) ────────────────────────────────────
select t.as_user('00000000-0000-0000-0000-00000000000c');
select app_login('07500000003', 'deptpass1');
select t.check(t.rows($$update departments set name_ku = 'x' where id = 1$$) = 1, 'department edits own');
select t.check(t.rows($$update departments set name_ku = 'x' where id = 2$$) = 0, 'department cannot edit other');
select t.check(t.rows($$insert into department_services(department_id, name) values (1, 's')$$) = 1, 'department adds own service');
select t.check(t.rows($$insert into department_services(department_id, name) values (2, 's')$$) = -1, 'department cannot add to other');

-- ── admin ────────────────────────────────────────────────────────
select t.as_user('00000000-0000-0000-0000-00000000000d');
select app_login('07500000001', 'adminpass');
select t.check((select count(*) from app_users) = 4, 'admin reads users');
select t.check((select count(*) from complaints) = 2, 'admin reads all complaints');
select t.check(t.rows($$update complaints set status = 'done'$$) = 2, 'admin updates complaints');
select t.check(t.rows($$insert into banners(title) values ('a')$$) = 1, 'admin adds banners');
select t.check(t.rows($$update app_users set is_approved = false where phone = '07500000002'$$) = 1, 'admin revokes vendor');

reset role;
select t.check((select role from app_sessions where auth_uid = '00000000-0000-0000-0000-00000000000b') = 'customer',
               'revoked vendor session drops to customer');
select t.check((select fcm_token from app_users where phone = '07500000002') = 'tok', 'fcm token saved via RPC');
select t.check((select bool_and(password like '$2%') from app_users), 'legacy passwords upgraded to bcrypt');
select t.check(not exists (select 1 from pg_policies where tablename = 'banners' and policyname = 'old_allow_all'),
               'old permissive policies removed');

-- ── per-user rows ────────────────────────────────────────────────
insert into favorite_stores(user_id, store_id) values ('999', 1);
insert into reviews(store_id, user_id, rating, is_approved) values (1, '999', 5, true), (1, '999', 1, false);
set role authenticated;
select t.as_user('00000000-0000-0000-0000-0000000000ee');   -- not logged in
select t.check((select count(*) from favorite_stores) = 0, 'cannot see others favorites');
select t.check(t.rows($$insert into favorite_stores(user_id, store_id) values ('999', 2)$$) = -1,
               'cannot add favorites for someone else');
select t.check(t.rows($$insert into news_likes(user_id) values ('00000000-0000-0000-0000-0000000000ee')$$) = 1,
               'anonymous user likes with auth id');
select t.check((select count(*) from news_likes) = 1, 'sees own like');
select t.check((select count(*) from reviews) = 1, 'only approved reviews are public');
select t.check(t.rows($$delete from reviews$$) = 0, 'cannot delete others reviews');
select t.as_user('00000000-0000-0000-0000-00000000000f');
select app_login('07500000004', 'custpass1');              -- customer, app id 4
select t.check(t.rows($$insert into favorite_stores(user_id, store_id) values ('4', 2)$$) = 1,
               'logged-in user adds favorite with app id');
select t.check(t.rows($$insert into reviews(store_id, user_id, rating) values (2, '4', 4)$$) = 1,
               'logged-in user writes review');
select t.check((select average_rating from dukan where id = 2) = 4, 'rating trigger still updates store');
select t.check(t.rows($$update reviews set rating = 1 where user_id = '4'$$) = 1, 'author edits own review');

select t.as_user('00000000-0000-0000-0000-00000000000d');
select app_login('07500000001', 'adminpass');
select t.check((select count(*) from reviews) = 3, 'admin sees all reviews');
select t.check(t.rows($$delete from reviews where is_approved = false$$) = 1, 'admin deletes reviews');

-- ── prayer times (admin still logged in) ─────────────────────────
select t.check(t.rows($$insert into prayer_times_official values
  ('07-11', '05:05', '06:30', '11:47', '14:37', '17:04', '18:15')$$) = 1, 'admin adds prayer day');
select t.check(t.rows($$insert into prayer_times_official values
  ('08-11', '05:06', '04:00', '11:47', '14:37', '17:04', '18:15')$$) = -2, 'times out of order rejected');
select t.check(t.rows($$insert into prayer_times_official values
  ('32-11', '05:05', '06:30', '11:47', '14:37', '17:04', '18:15')$$) = -2, 'bad day rejected');

select t.as_user('00000000-0000-0000-0000-0000000000ee');   -- guest
select t.check((select maghrib from prayer_times_official where day_month = '07-11') = '17:04', 'guest reads prayer times');
select t.check(t.rows($$update prayer_times_official set maghrib = '17:00'$$) = 0, 'guest cannot edit prayer times');
select t.check(t.rows($$insert into prayer_times_official values
  ('09-11', '05:07', '06:32', '11:47', '14:36', '17:02', '18:14')$$) = -1, 'guest cannot add prayer times');
select t.as_user('00000000-0000-0000-0000-00000000000d');

select app_logout();
select t.check(app_role() = 'guest', 'logout clears the session');

\echo 'ALL RLS TESTS PASSED'
