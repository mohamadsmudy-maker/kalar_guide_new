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
| 19 | `20261125_breaking_news_push.sql` | ئاگاداری push بۆ هەواڵی بەپەلە (news_tickers.notified_at) | ✅ |
| 20 | `20261126_complaint_push.sql` | ئاگاداری push بۆ ئەدمین کاتی سکاڵای نوێ (complaints.notified_at) | ✅ |
| 21 | `20261127_pharmacy_duty.sql` | دەرمانخانەی ئێشکگر (خشتەی pharmacy_duty) | ✅ |
| 22 | `20261128_complaint_status_push.sql` | ئاگادارکردنەوەی هاوڵاتی کاتی گۆڕانی دۆخی سکاڵاکەی (complaints.status_notified) | ✅ |
| 23 | `20261129_neighborhood_alerts.sql` | ئاگاداریی گەڕەک (خشتەی neighborhood_alerts) | ✅ |
| 24 | `20261130_news_shares.sql` | ژمارەی شێری هەواڵ (news.shares + increment_news_shares) | ✅ |
| 25 | `20261201_review_reports.sql` | ڕاپۆرتکردنی کۆمێنت (review_reports + app_report_review) — Google Play پێویستی پێیەتی | ✅ |
| 26 | `20261202_featured_places.sql` | شوێنی پێشنیارکراو (dukan.featured_until، تەنها ئەدمین) | ✅ |
| 27 | `20261203_waste_schedule.sql` | کاتی هاتنی ئۆتۆمبێلی خۆڵ بۆ هەر گەڕەکێک (waste_schedule) | ✅ |
| 28 | `20261204_sponsored_slides.sql` | سلایدی ڕیکلام لە پەیجی سەرەکی (sponsored_slides + app_sponsored_event) | ✅ |

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
          and table_name = 'dukan' and column_name = 'prices_active')            as m18_price_station_active,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'news_tickers' and column_name = 'notified_at')       as m19_breaking_news_push,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'complaints' and column_name = 'notified_at')         as m20_complaint_push,
  to_regclass('public.pharmacy_duty')                                            is not null as m21_pharmacy_duty,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'complaints' and column_name = 'status_notified')     as m22_complaint_status_push,
  to_regclass('public.neighborhood_alerts')                                      is not null as m23_neighborhood_alerts,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'news' and column_name = 'shares')                     as m24_news_shares,
  to_regclass('public.review_reports')                                           is not null as m25_review_reports,
  exists (select 1 from information_schema.columns where table_schema = 'public'
          and table_name = 'dukan' and column_name = 'featured_until')            as m26_featured_places,
  to_regclass('public.waste_schedule')                                           is not null as m27_waste_schedule,
  to_regclass('public.sponsored_slides')                                         is not null as m28_sponsored_slides;
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
| `send-complaint-notification` | سکاڵای نوێ → ئەدمین؛ گۆڕانی دۆخ → هاوڵاتی | `FIREBASE_SERVICE_ACCOUNT_KEY` |
| `send-breaking-news` | ئاگاداری push بۆ هەواڵی بەپەلە | `FIREBASE_SERVICE_ACCOUNT_KEY` |
| `send-neighborhood-alert` | ئاگاداری push بۆ گەڕەکێک | `FIREBASE_SERVICE_ACCOUNT_KEY` |

نهێنییەکان: Supabase ← **Edge Functions ← Secrets**.

### ⚡ ئاگاداری هەواڵی بەپەلە — یەکجار ڕێکی بخە

1. مایگرەیشنی ١٩ (`20261125_breaking_news_push.sql`) جێبەجێ بکە.
2. فەنکشنی `send-breaking-news` دابنێ (GitHub ← Actions ← *Deploy Supabase function*). ئەگەر
   لە داشبۆردەوە دروستی دەکەیت، **Verify JWT** ناچالاک بکە.
3. `FIREBASE_SERVICE_ACCOUNT_KEY`: Firebase ← Project settings ← **Service accounts** ←
   *Generate new private key* ← ناوەڕۆکی تەواوی فایلە JSON ـەکە لە Supabase ← Edge Functions ← Secrets دابنێ.
   (ئەم فایلە نهێنییە؛ بۆ کەسی مەنێرە.)
4. Supabase ← **Database ← Webhooks** ← *Create a new hook*:
   - Table: `news_tickers` — Events: **Insert** و **Update**
   - Type: **Supabase Edge Functions** ← `send-breaking-news` ← Method: `POST`

هەر هەواڵێک تەنها یەکجار دەنێردرێت. وەشانی ئێستای ئەپ تەنها بۆ ئەوانە دەگات کە چوونەتە ژوورەوە؛
لە وەشانی داهاتوودا هەموو مۆبایلەکان (میوانیش) وەری دەگرن.

### 📣 ئاگاداری سکاڵای نوێ بۆ ئەدمین — یەکجار ڕێکی بخە

هەمان Secret ـی `FIREBASE_SERVICE_ACCOUNT_KEY` بەکاردێت. سەرەڕای ئەوە:
1. مایگرەیشنی ٢٠ (`20261126_complaint_push.sql`) جێبەجێ بکە.
2. فەنکشنی `send-complaint-notification` دووبارە دابنێ (Verify JWT ناچالاک).
3. Webhook ـێکی تر: Table `complaints` — Events: **Insert** و **Update** — Type: Supabase Edge Functions ← `send-complaint-notification` ← `POST`.
   (Update بۆ ئاگادارکردنەوەی هاوڵاتی کاتی گۆڕانی دۆخ؛ مایگرەیشنی ٢٢ پێویستە.)

ئەدمین تەنها کاتێک وەری دەگرێت کە لە ئەپدا چووبێتە ژوورەوە (token ـەکەی پاشەکەوت کرابێت).
هاوڵاتیش تەنها ئەگەر لە کاتی ناردنی سکاڵاکەدا چووبێتە ژوورەوە.

### 📍 ئاگاداریی گەڕەک — یەکجار ڕێکی بخە

1. مایگرەیشنی ٢٣ (`20261129_neighborhood_alerts.sql`) جێبەجێ بکە.
2. فەنکشنی `send-neighborhood-alert` دابنێ (Verify JWT ناچالاک).
3. Webhook: Table `neighborhood_alerts` — Event: **Insert** — `send-neighborhood-alert` ← `POST`.

هاوڵاتی لە شاشەی گەڕەکەکەیدا ئاگادارییەکان چالاک دەکات (پێویستی بە وەشانی نوێی ئەپە).
