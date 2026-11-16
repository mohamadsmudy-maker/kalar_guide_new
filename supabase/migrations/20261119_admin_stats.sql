-- ═══════════════════════════════════════════════════════════════════
-- 📊 Kalar Guide — admin statistics + anonymous search log
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- • search_logs        what people typed in the global search and how many
--                      results it had (no user id, no device id). Only the
--                      admin can read it. Phone-number-like text is never kept.
-- • app_log_search()   the app calls this; it cleans and stores one row
-- • app_admin_stats()  one call returns every number the admin statistics
--                      screen shows. Admin only. Each section is computed on
--                      its own: if a table or column is missing in this
--                      project, only that section comes back null.
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.search_logs (
  id         bigserial primary key,
  q          text not null check (length(q) between 2 and 80),
  results    int  not null default 0 check (results >= 0),
  lang       text,
  created_at timestamptz not null default now()
);
create index if not exists search_logs_created_idx on public.search_logs (created_at desc);

alter table public.search_logs enable row level security;
drop policy if exists admin_select on public.search_logs;
drop policy if exists admin_delete on public.search_logs;
create policy admin_select on public.search_logs for select using (public.app_is_admin());
create policy admin_delete on public.search_logs for delete using (public.app_is_admin());
grant select, delete on public.search_logs to authenticated;

create or replace function public.app_log_search(p_q text, p_results int, p_lang text)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v text := lower(btrim(regexp_replace(coalesce(p_q, ''), '\s+', ' ', 'g')));
begin
  if length(v) < 2 or length(v) > 80 then return; end if;
  -- phone numbers, ids, card numbers: never stored
  if v ~ '[0-9٠-٩۰-۹]{7,}' then return; end if;
  insert into public.search_logs (q, results, lang)
  values (v, greatest(coalesce(p_results, 0), 0), left(coalesce(p_lang, ''), 5));
end;
$$;
grant execute on function public.app_log_search(text, int, text) to anon, authenticated;

create or replace function public.app_admin_stats(p_days int default 30)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  d        int  := greatest(1, least(coalesce(p_days, 30), 365));
  tz       constant text := 'Asia/Baghdad';
  t_now    timestamptz := now();
  t_from   timestamptz := now() - make_interval(days => d);
  t_prev   timestamptz := now() - make_interval(days => 2 * d);
  d_today  date := (now() at time zone 'Asia/Baghdad')::date;
  d_from   date := (now() at time zone 'Asia/Baghdad')::date - (d - 1);
  r        jsonb := jsonb_build_object('days', d, 'generated_at', now());
  x        jsonb;
  daily    jsonb;
begin
  if not coalesce(public.app_is_admin(), false) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- ── totals ─────────────────────────────────────────────────────
  begin
    x := jsonb_build_object(
      'places',      (select count(*) from public.dukan),
      'departments', (select count(*) from public.departments),
      'news',        (select count(*) from public.news),
      'events',      (select count(*) from public.events),
      'users',       (select count(*) from public.app_users),
      'complaints',  (select count(*) from public.complaints));
  exception when others then x := null; end;
  r := r || jsonb_build_object('totals', x);

  -- ── complaints ─────────────────────────────────────────────────
  begin
    select coalesce(jsonb_agg(jsonb_build_object('d', to_char(g.dd, 'YYYY-MM-DD'), 'n', coalesce(c.n, 0))
                              order by g.dd), '[]'::jsonb)
      into daily
      from generate_series(d_from::timestamp, d_today::timestamp, interval '1 day') as g(dd)
      left join (select (created_at at time zone tz)::date as day, count(*) as n
                   from public.complaints where created_at >= t_from - interval '1 day' group by 1) c
        on c.day = g.dd::date;
    x := jsonb_build_object(
      'now',  (select count(*) from public.complaints where created_at >= t_from),
      'prev', (select count(*) from public.complaints where created_at >= t_prev and created_at < t_from),
      'pending',  (select count(*) from public.complaints where status = 'pending'),
      'resolved', (select count(*) from public.complaints where status = 'completed' and created_at >= t_from),
      'daily', daily,
      'by_status', (select coalesce(jsonb_object_agg(s, n), '{}'::jsonb)
                      from (select coalesce(status, 'pending') as s, count(*) as n
                              from public.complaints where created_at >= t_from group by 1) q),
      'top_neighborhoods', (select coalesce(jsonb_agg(jsonb_build_object('name', nm, 'n', n) order by n desc, nm), '[]'::jsonb)
                              from (select btrim(neighborhood_name) as nm, count(*) as n
                                      from public.complaints
                                     where created_at >= t_from and btrim(coalesce(neighborhood_name, '')) <> ''
                                     group by 1 order by 2 desc, 1 limit 6) q),
      'top_authorities', (select coalesce(jsonb_agg(jsonb_build_object('name', nm, 'n', n) order by n desc, nm), '[]'::jsonb)
                            from (select btrim(responsible_authority) as nm, count(*) as n
                                    from public.complaints
                                   where created_at >= t_from and btrim(coalesce(responsible_authority, '')) <> ''
                                   group by 1 order by 2 desc, 1 limit 6) q));
    begin
      x := x || jsonb_build_object('avg_resolution_hours',
        (select round((avg(extract(epoch from (updated_at - created_at)) / 3600))::numeric, 1)
           from public.complaints
          where status = 'completed' and created_at >= t_from and updated_at >= created_at));
    exception when others then null; end;
  exception when others then x := null; end;
  r := r || jsonb_build_object('complaints', x);

  -- ── users ──────────────────────────────────────────────────────
  begin
    select coalesce(jsonb_agg(jsonb_build_object('d', to_char(g.dd, 'YYYY-MM-DD'), 'n', coalesce(c.n, 0))
                              order by g.dd), '[]'::jsonb)
      into daily
      from generate_series(d_from::timestamp, d_today::timestamp, interval '1 day') as g(dd)
      left join (select (created_at at time zone tz)::date as day, count(*) as n
                   from public.app_users where created_at >= t_from - interval '1 day' group by 1) c
        on c.day = g.dd::date;
    x := jsonb_build_object(
      'now',  (select count(*) from public.app_users where created_at >= t_from),
      'prev', (select count(*) from public.app_users where created_at >= t_prev and created_at < t_from),
      'daily', daily,
      'by_role', (select coalesce(jsonb_object_agg(rl, n), '{}'::jsonb)
                    from (select coalesce(role, 'customer') as rl, count(*) as n from public.app_users group by 1) q));
    begin
      x := x || jsonb_build_object(
        'online', (select count(*) from public.active_users where last_seen > now() - interval '5 minutes'),
        'by_language', (select coalesce(jsonb_object_agg(l, n), '{}'::jsonb)
                          from (select coalesce(nullif(language, ''), '?') as l, count(*) as n
                                  from public.active_users where last_seen >= t_from group by 1) q),
        'by_platform', (select coalesce(jsonb_object_agg(p, n), '{}'::jsonb)
                          from (select coalesce(nullif(platform, ''), '?') as p, count(*) as n
                                  from public.active_users where last_seen >= t_from group by 1) q));
    exception when others then null; end;
  exception when others then x := null; end;
  r := r || jsonb_build_object('users', x);

  -- ── places ─────────────────────────────────────────────────────
  begin
    x := jsonb_build_object(
      'now',  (select count(*) from public.dukan where created_at >= t_from),
      'prev', (select count(*) from public.dukan where created_at >= t_prev and created_at < t_from),
      'by_category', (select coalesce(jsonb_agg(jsonb_build_object('name', c, 'n', n) order by n desc, c), '[]'::jsonb)
                        from (select btrim(category) as c, count(*) as n from public.dukan
                               where btrim(coalesce(category, '')) <> '' group by 1 order by 2 desc, 1 limit 8) q));
    begin
      x := x || jsonb_build_object('top_rated',
        (select coalesce(jsonb_agg(jsonb_build_object('name', name, 'rating', rt, 'reviews', rv) order by rt desc, rv desc), '[]'::jsonb)
           from (select name, round(average_rating::numeric, 1) as rt, coalesce(total_reviews, 0) as rv
                   from public.dukan where coalesce(average_rating, 0) > 0 and coalesce(total_reviews, 0) >= 1
                   order by average_rating desc, total_reviews desc limit 5) q));
    exception when others then null; end;
    begin
      x := x || jsonb_build_object('top_favorited',
        (select coalesce(jsonb_agg(jsonb_build_object('name', name, 'n', n) order by n desc, name), '[]'::jsonb)
           from (select s.name, count(*) as n from public.favorite_stores f
                   join public.dukan s on s.id::text = f.store_id::text
                  group by s.name order by 2 desc, 1 limit 5) q));
    exception when others then null; end;
  exception when others then x := null; end;
  r := r || jsonb_build_object('places', x);

  -- ── content ────────────────────────────────────────────────────
  begin
    x := jsonb_build_object(
      'top_news', (select coalesce(jsonb_agg(jsonb_build_object('name', title, 'views', v, 'likes', l) order by v desc, title), '[]'::jsonb)
                     from (select title, coalesce(views, 0) as v, coalesce(likes, 0) as l
                             from public.news order by coalesce(views, 0) desc, title limit 5) q),
      'top_events', (select coalesce(jsonb_agg(jsonb_build_object('name', title, 'views', v) order by v desc, title), '[]'::jsonb)
                       from (select title, coalesce(views, 0) as v
                               from public.events order by coalesce(views, 0) desc, title limit 5) q));
  exception when others then x := null; end;
  r := r || jsonb_build_object('content', x);

  -- ── search ─────────────────────────────────────────────────────
  begin
    x := jsonb_build_object(
      'now',  (select count(*) from public.search_logs where created_at >= t_from),
      'prev', (select count(*) from public.search_logs where created_at >= t_prev and created_at < t_from),
      'top', (select coalesce(jsonb_agg(jsonb_build_object('name', q, 'n', n) order by n desc, q), '[]'::jsonb)
                from (select q, count(*) as n from public.search_logs
                       where created_at >= t_from group by 1 order by 2 desc, 1 limit 8) s),
      'no_results', (select coalesce(jsonb_agg(jsonb_build_object('name', q, 'n', n) order by n desc, q), '[]'::jsonb)
                       from (select q, count(*) as n from public.search_logs
                              where created_at >= t_from and results = 0 group by 1 order by 2 desc, 1 limit 8) s));
  exception when others then x := null; end;
  r := r || jsonb_build_object('search', x);

  return r;
end;
$$;
grant execute on function public.app_admin_stats(int) to anon, authenticated;

notify pgrst, 'reload schema';
