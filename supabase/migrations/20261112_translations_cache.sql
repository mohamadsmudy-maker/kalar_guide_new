-- ═══════════════════════════════════════════════════════════════════
-- 🌍 Kalar Guide — shared translation cache for database text
-- ═══════════════════════════════════════════════════════════════════
-- Run AFTER 20261108_rls_lockdown.sql. Safe to run more than once.
--
-- Place names, news and categories are translated by Gemini (Edge
-- Function translate-text). Without this table every phone translated
-- the same texts again. Now each text is translated once, stored here,
-- and every phone reads it from here:
--   • the Edge Function looks here first and only calls Gemini on a miss;
--   • the app downloads all rows for its language in one request;
--   • the admin can correct a translation (edited = true is never
--     overwritten by Gemini).
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.translations (
  lang        text not null check (lang in ('en', 'ar')),
  source      text not null check (length(source) between 1 and 5000),
  -- long texts cannot be indexed directly, so rows are keyed by a hash
  source_hash text generated always as (md5(source)) stored,
  translation text not null check (length(translation) > 0),
  edited      boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (lang, source_hash)
);

create index if not exists translations_lang_updated_idx
  on public.translations (lang, updated_at desc);

alter table public.translations enable row level security;

drop policy if exists read_all     on public.translations;
drop policy if exists admin_insert on public.translations;
drop policy if exists admin_update on public.translations;
drop policy if exists admin_delete on public.translations;

-- everyone reads; only the admin changes rows by hand.
-- The Edge Function writes with the service role, which bypasses RLS.
create policy read_all     on public.translations for select using (true);
create policy admin_insert on public.translations for insert with check (public.app_is_admin());
create policy admin_update on public.translations for update
  using (public.app_is_admin()) with check (public.app_is_admin());
create policy admin_delete on public.translations for delete using (public.app_is_admin());

grant select on public.translations to anon, authenticated;
grant insert, update, delete on public.translations to authenticated;

-- Used by the Edge Function (service role only): read one translation /
-- store a new one. A stored row is never overwritten, so an admin
-- correction (or the first good translation) stays.
create or replace function public.translation_get(p_lang text, p_source text)
returns text
language sql stable security definer
set search_path = public
as $$
  select t.translation from public.translations t
   where t.lang = p_lang and t.source_hash = md5(p_source) and t.source = p_source;
$$;

create or replace function public.translation_put(p_lang text, p_source text, p_translation text)
returns void
language sql security definer
set search_path = public
as $$
  insert into public.translations (lang, source, translation)
  values (p_lang, p_source, p_translation)
  on conflict (lang, source_hash) do nothing;
$$;

revoke all on function public.translation_get(text, text) from public, anon, authenticated;
revoke all on function public.translation_put(text, text, text) from public, anon, authenticated;
do $$ begin
  grant execute on function public.translation_get(text, text) to service_role;
  grant execute on function public.translation_put(text, text, text) to service_role;
exception when undefined_object then null;   -- plain Postgres (tests) has no service_role
end $$;

-- 🔙 ROLLBACK
-- drop function public.translation_put(text, text, text);
-- drop function public.translation_get(text, text);
-- drop table public.translations;
