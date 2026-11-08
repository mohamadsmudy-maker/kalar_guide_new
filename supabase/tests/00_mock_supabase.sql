-- Minimal stand-in for the Supabase schema, used only by CI to test the
-- migrations on a plain Postgres. Not for production.
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
create schema auth; create schema extensions;
create extension if not exists pgcrypto with schema extensions;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
grant usage on schema auth, public, extensions to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
create table app_users(id bigserial primary key, name text, phone text, password text, role text, is_approved boolean, store_id bigint, fcm_token text, created_at timestamptz default now());
create table dukan(id bigserial primary key, name text, phone text, category text, vendor_code text, fuel_prices jsonb, currency_prices jsonb);
create table news(id uuid primary key default gen_random_uuid(), title text, store_id bigint, views int default 0, likes int default 0);
create table store_services(id bigserial primary key, store_id bigint, name text);
create table products(id bigserial primary key, store_id bigint, name text);
create table currency_price_history(id bigserial primary key, station_id bigint, price numeric);
create table fuel_price_history(id bigserial primary key, station_id bigint, price numeric);
create table departments(id bigserial primary key, name_ku text, user_phone text);
create table department_services(id bigserial primary key, department_id bigint, name text);
create table complaints(id bigserial primary key, user_id text, status text default 'pending', admin_notes text);
create table events(id bigserial primary key, title text, views int default 0);
create table banners(id bigserial primary key, title text);
create table weather(id bigserial primary key, temp int);
create table main_categories(id bigserial primary key, name text);
create table reviews(id bigserial primary key, store_id bigint, user_id text, rating int, is_approved boolean default true);
alter table dukan add column average_rating numeric default 0;
create function refresh_rating() returns trigger language plpgsql as $f$
begin
  update dukan set average_rating = (select avg(rating) from reviews r where r.store_id = new.store_id) where id = new.store_id;
  return new;
end $f$;
create trigger reviews_rating after insert on reviews for each row execute function refresh_rating();
create table news_likes(id bigserial primary key, user_id text, news_id uuid);
create table news_favorites(id bigserial primary key, user_id text, news_id uuid);
create table favorite_stores(id bigserial primary key, user_id text, store_id bigint);
create table event_interests(id bigserial primary key, user_id text, event_id bigint);
create function increment_views(news_id uuid) returns void language sql as $$ update news set views = views + 1 where id = news_id $$;
create policy old_allow_all on banners for all using (true) with check (true);
alter table banners enable row level security;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;

-- An older app_current_user with another return type already exists in the
-- real project; the migration must replace it.
create function app_current_user() returns json language sql as $$ select '{}'::json $$;
create function app_is_admin() returns integer language sql as $$ select 0 $$;
