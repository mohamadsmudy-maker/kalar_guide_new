# 🗄️ ڕیزبەندی مایگرەیشنەکانی Supabase

هەموو فایلەکان لە `supabase/migrations/` دان. لە **Supabase ← SQL Editor** بەپێی ڕیز جێبەجێیان بکە
(هەر فایلێک: کۆپی ← Paste ← Run). ئەوانەی نووسراوە «ئاسایە دووبارە جێبەجێ بکرێت» هیچ زیانێک نییە
ئەگەر دووبارە بکرێن.

| # | فایل | بۆ چی | دووبارە بکرێت؟ |
|---|---|---|---|
| 1 | `20261107_secure_login.sql` | چوونەژوورەوە و تۆمارکردن لە سێرڤەر (پاسۆرد هەرگیز لە مۆبایل ناپشکنرێت) | ⚠️ یەکجار |
| 2 | `20261108_rls_lockdown.sql` | پاراستنی خشتەکان بە RLS (ڕۆڵی ئەدمین/ڤێندەر) | ⚠️ یەکجار |
| 3 | `20261109_rls_user_tables.sql` | پاراستنی دڵخواز، لایک، هەڵسەنگاندن | ⚠️ یەکجار |
| 4 | `20261110_prayer_times.sql` | کاتەکانی نوێژی فەرمی کە ئەدمین دەیگۆڕێت | ⚠️ یەکجار |
| 5 | `20261111_price_updates.sql` | گۆڕینی نرخی سووتەمەنی و دراو لە ڕێگەی سێرڤەرەوە | ✅ |
| 6 | `20261112_translations_cache.sql` | کاشی هاوبەشی وەرگێڕانی ناوی شوێن و هەواڵ | ✅ |
| 7 | `20261113_google_login.sql` | چوونەژوورەوە بە Google + سڕینەوەی ئەکاونت | ✅ |
| 8 | `20261114_effective_role.sql` | ڕۆڵی ڕاستەقینەی بەکارهێنەر | ✅ |
| 9 | `20261115_places_sources.sql` | سەرچاوەی شوێنەکان + پێشنیاری شوێنی هاوڵاتیان | ✅ |
| 10 | `20261116_price_phone_match.sql` | ڤێندەر نرخی شوێنی خۆی بگۆڕێت (بە ژمارەی مۆبایل) | ✅ |
| 11 | `20261117_department_places.sql` | فەرمانگە لە شوێنە تۆمارکراوەکانەوە + پێداویستی و تێچووی مامەڵەکان | ✅ |
| 12 | `20261118_price_types.sql` | جۆرەکانی سووتەمەنی و دراو لەلایەن ئەدمینەوە بگۆڕدرێن (زیادکردن، سڕینەوە، ڕیزکردن) | ✅ |
| 13 | `20261119_admin_stats.sql` | ئاماری ئەدمین + تۆمارکردنی گەڕانی بێناسنامە (بۆ ناوەندی کۆنترۆڵ) | ✅ |
| 14 | `20261120_presence_and_hours.sql` | بەکارهێنەرانی چالاک بە ڕاستی دەژمێردرێن + کاتی کارکردنی شوێنەکان | ✅ |
| 15 | `20261121_translations_fa.sql` | زیادکردنی 'fa' (فارسی) بۆ چەکی lang لە text_translations | ✅ |
| 16 | `20261122_news_rls_fix.sql` | چارەسەری هەڵەی RLS ی هەواڵ بۆ ڤێندەرانی store_id کۆن | ✅ |
| 17 | `20261123_news_tickers.sql` | توڵی هەواڵی بەپەلە (جەدوەلی news_tickers + RLS) | ✅ |
| 18 | `20261124_price_station_active.sql` | چالاک/ناچالاککردنی نرخی بەنزینخانە و نوسینگەی دراو (dukan.prices_active) | ✅ |

> ئەگەر نازانیت کامیان پێشتر جێبەجێ کراوە، ئەم پشکنینە لە SQL Editor بکە. `true` واتە کراوە:

```sql
select
  to_regprocedure('public.app_login(text,text)')                  is not null as m01_secure_login,
  to_regprocedure('public.app_role()')                            is not null as m02_rls_lockdown,
  to_regprocedure('public.app_is_owner(text)')                    is not null as m03_user_tables,
  to_regclass('public.prayer_times_official')                     is not null as m04_prayer_times,
  to_regprocedure('public.app_update_fuel_price(bigint,text,numeric,text)')   is not null as m05_price_updates,
  to_regclass('public.text_translations')                         is not null as m06_translations,
  to_regprocedure('public.app_delete_account()')                  is not null as m07_google_login,
  to_regprocedure('public.app_current_user()')                    is not null as m08_effective_role,
  to_regclass('public.place_suggestions')                         is not null as m09_places_sources,
  to_regprocedure('public.app_phone_key(text)')                   is not null as m10_price_phone,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'departments' and column_name = 'place_id')          as m11_department_places,
  to_regclass('public.price_types')                               is not null as m12_price_types,
  to_regprocedure('public.app_admin_stats(int)')                  is not null as m13_admin_stats,
  to_regprocedure('public.get_presence_stats()')                  is not null as m14_presence_hours,
  exists (select 1 from information_schema.check_constraints where constraint_schema = 'public'
          and constraint_name = 'text_translations_lang_check'
          and check_clause like '%fa%')                                          as m15_translations_fa,
  -- m16: app_owns() دووبارە دروست کراوەتەوە (ئایا fallback هەیە؟)
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'app_owns'
          and p.prosrc like '%app_users u%')                                     as m16_news_rls_fix,
  to_regclass('public.news_tickers')                                             is not null as m17_news_tickers,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'dukan' and column_name = 'prices_active')            as m18_price_station_active;
```

## Edge Functions (جیا لە SQL)

لە `supabase/functions/` دان. بۆ deploy کردن: Supabase ← **Edge Functions**، یان بە CLI:
`supabase functions deploy <ناو>`.

**ئاسانترین ڕێگا (بێ کۆپی و پەیست):** GitHub ← **Actions** ← *Deploy Supabase function* ← **Run workflow** ←
فەنکشنەکە هەڵبژێرە. یەکجار ئەم دوو Secret ـە لە GitHub ← Settings ← Secrets and variables ← Actions دابنێ:
`SUPABASE_ACCESS_TOKEN` (لە supabase.com/dashboard/account/tokens) و `SUPABASE_PROJECT_REF` (ناسنامەی پڕۆژە).
ئەمە وەشانی ناو گیت دادەنێت و ئەو گۆڕانکارییانەی ڕاستەوخۆ لە داشبۆرد کراون لەسەر ئەو فەنکشنە دەسڕێتەوە.

| فەنکشن | بۆ چی | نهێنی (Secrets) ی پێویست |
|---|---|---|
| `translate-text`، `gemini-proxy` | وەرگێڕان بە Gemini | `GEMINI_API_KEY` (هەرگیز لە ئەپەکەدا نا)؛ ئارەزوومەندانە `GEMINI_MODEL` |
| `places-search`، `places-nearby`، `places-details` | گەڕانی شوێن | `GOOGLE_PLACES_API_KEY` |
| `hash-password` | هاشکردنی پاسۆرد | `PASSWORD_SALT` |
| `register-customer`، `register-vendor` | تۆمارکردن | (`SUPABASE_URL` و `SUPABASE_SERVICE_ROLE_KEY` خۆکارانە دەدرێن) |
| `send-complaint-notification` | ئاگاداری سکاڵا | `FIREBASE_SERVICE_ACCOUNT_KEY` |

نهێنییەکان: Supabase ← **Edge Functions ← Secrets**.
