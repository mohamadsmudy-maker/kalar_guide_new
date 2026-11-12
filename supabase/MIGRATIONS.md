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
  to_regprocedure('public.app_phone_key(text)')                   is not null as m10_price_phone;
```

## Edge Functions (جیا لە SQL)

لە `supabase/functions/` دان. بۆ deploy کردن: Supabase ← **Edge Functions**، یان بە CLI:
`supabase functions deploy <ناو>`.

| فەنکشن | بۆ چی | نهێنی (Secrets) ی پێویست |
|---|---|---|
| `translate-text`، `gemini-proxy` | وەرگێڕان بە Gemini | `GEMINI_API_KEY` (هەرگیز لە ئەپەکەدا نا)؛ ئارەزوومەندانە `GEMINI_MODEL` |
| `places-search`، `places-nearby`، `places-details` | گەڕانی شوێن | `GOOGLE_PLACES_API_KEY` |
| `hash-password` | هاشکردنی پاسۆرد | `PASSWORD_SALT` |
| `register-customer`، `register-vendor` | تۆمارکردن | (`SUPABASE_URL` و `SUPABASE_SERVICE_ROLE_KEY` خۆکارانە دەدرێن) |
| `send-complaint-notification` | ئاگاداری سکاڵا | `FIREBASE_SERVICE_ACCOUNT_KEY` |

نهێنییەکان: Supabase ← **Edge Functions ← Secrets**.
