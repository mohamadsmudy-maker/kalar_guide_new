-- ═══════════════════════════════════════════════════════════════════
-- 🔐 Kalar Guide — fix vendor news insert (stale session store_id)
-- ═══════════════════════════════════════════════════════════════════
-- کێشە: ئەگەر ڤێندەر لەمەوپێش چووبێتەژوورەوە، پێش ئەوەی ئەدمین
-- store_id ـی لە app_users دیاری بکات، app_sessions.store_id = NULL
-- دەمێنێتەوە. app_owns() ئەوا فەیل دەبێت.
--
-- چارەسەر: app_owns() دووبارە دروست بکەرەوە بۆ ئەوەی app_users
-- بە مستەقیم پشکنی بۆ fallback.
-- Safe to run more than once.
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.app_owns(p_store_id text, p_role text)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.app_role() = 'admin'
      or (public.app_role() = p_role
          and p_store_id is not null
          and (
            -- ١) ئۆپشنی خێرا: store_id ی session ـ لەگەڵ ئەو شوێنە دەگونجێت
            public.app_store_id() = p_store_id
            -- ٢) fallback: app_users بە مستەقیم پشکنە (session کۆن بوو)
            or exists (
              select 1
                from public.app_users u
                join public.app_sessions s on s.user_id = u.id::text
               where s.auth_uid  = auth.uid()
                 and u.store_id::text = p_store_id
            )
          ));
$$;

grant execute on function public.app_owns(text, text) to anon, authenticated;
