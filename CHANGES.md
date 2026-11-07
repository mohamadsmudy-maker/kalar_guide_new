# گۆڕانکارییەکانی lib — ڕێبەری کەلار

> ⚠️ **ڕیزبەندی گرنگ:** یەکەم جار فایلی SQL لە Supabase ڕابکە، پاشان ئەپی نوێ بیلد بکە.
> ئەگەر ئەپی نوێ پێش SQL ـەکە بڵاو بکەیتەوە، چوونەژوورەوە کار ناکات.

## چۆن دایبنێیت

1. لە Supabase بڕۆ بۆ **SQL Editor**، ناوەڕۆکی `supabase/migrations/20261107_secure_login.sql` بلکێنە و **Run** بکە.
2. ئەگەر بەکارهێنەری کۆنت هەیە کە پاسۆردەکەیان بە SHA-256 هاش کراوە، ئەمەش یەکجار ڕابکە:
   `ALTER DATABASE postgres SET app.password_salt = 'هەمان PASSWORD_SALT ی کۆن';`
3. فۆڵدەری `lib/` ی کۆن بگۆڕە بەم `lib/` ـە نوێیە.
4. `pubspec.yaml` و `l10n.yaml` بخەرە ڕەگی پرۆژەکە.
5. فایلی `test/utils/password_hasher_test.dart` بسڕەوە (فایلە تاقیکراوەکەی چیتر نەماوە).
6. ئەم فەرمانانە ڕابکە:
   ```
   flutter clean
   flutter pub get
   flutter analyze
   ```

---

## 🔴 ئاسایش

| کێشە | چاککردن |
|---|---|
| لە کاتی چوونەژوورەوەدا هەموو ڕیزی `app_users` (لەگەڵ هاشی پاسۆرد) دەهێنرایە سەر مۆبایل و لەوێ پشکنین دەکرا | ئێستا RPCـی `app_login` پاسۆرد لەسەر سێرڤەر پشکنین دەکات. هاش هەرگیز ناگاتە مۆبایل |
| `vendor_code`ـی **هەموو شوێنەکان** دادەبەزێنرا بۆ مۆبایل، بۆیە هەرکەسێک دەیتوانی بیبینێت | ئیتر دانابەزێنرێت. پشکنین بە RPCـی `verify_vendor_code` لەسەر سێرڤەر دەکرێت |
| مۆبایل خۆی `role` و `is_approved`ـی دەنووسی لە کاتی تۆمارکردن | تۆمارکردن بە RPCـی `app_register_customer` و `app_request_vendor` دەکرێت. ڕۆڵ لەسەر سێرڤەر دیاری دەکرێت |
| پاسۆردی plaintext و SHA-256 قبووڵ دەکران | لە یەکەم چوونەژوورەوەدا لەسەر سێرڤەر دەگۆڕدرێن بۆ bcrypt |
| هەڵەی ناوخۆیی (`'هەڵە: $e'`) نیشانی بەکارهێنەر دەدرا | ئێستا تەنها پەیامێکی گشتی نیشان دەدرێت |
| `PASSWORD_SALT` لە ناو ئەپەکەدا بوو | لابرا. ئێستا تەنها لە داتابەیسدایە |

**فایلە سڕاوەکان:** `utils/password_hasher.dart`، `providers/auth_providers.dart`، `data/repositories/auth_repository.dart` (ئەم دووانەی دوایی خشتەی کۆنی `users`ـیان بەکاردەهێنا و هیچ شوێنێک import ی نەدەکردن)

### ⚠️ کارێک کە هێشتا دەبێت لەسەر سێرڤەر بکرێت

- **دوای ئەوەی هەموو بەکارهێنەران ئەپەکەیان نوێ کردەوە:** بەشی ٥ی فایلی SQL ـەکە بکەرەوە، بۆ ئەوەی کەس نەتوانێت ستوونی `password` و `vendor_code` بخوێنێتەوە.
- **ڕۆڵی ئەدمین هێشتا تەنها لەسەر مۆبایل پشکنین دەکرێت.** ژمارەی مۆبایل لە `SharedPreferences` هەڵدەگیرێت. پاراستنی ڕاستەقینە پێویستی بە **RLS** هەیە لەسەر هەموو خشتەکان، یان گواستنەوە بۆ **Supabase Auth**. ئەمە کارێکی گەورەی سێرڤەرە و لە دەرەوەی `lib/`ـە.
- دڵنیا بەرەوە کە RPCـی `get_user_for_login` ستوونی `password` ناگەڕێنێتەوە.

---

## 🟠 هەڵەی کۆمپایل (import ی هەڵە) — ١٦ دانە، لە ٧ فایل

ڕێڕەوی import ـەکان یەک ئاست زیادەیان تێدابوو (`../../../` لە جیاتی `../../`)، بۆیە بە دەرەوەی `lib/` دەگەیشتن:

- `screens/emergency/emergency_main_screen.dart` (٥ import)
- `screens/prayer/adhan_settings_screen.dart`
- `screens/prayer/prayer_settings_screen.dart`
- `widgets/neighborhoods_drawer.dart`
- `widgets/neighborhood_info_sheet.dart`
- `widgets/search_bar_widget.dart`
- `providers/auth_providers.dart` (پاشان سڕایەوە)

## 🟠 هەڵەی تر

- **تۆمارکردن تێکدەچوو:** فۆڕمەکە پاسۆردی ٦ پیتی قبووڵ دەکرد، بەڵام `PasswordHasher` دەیویست لانیکەم ٨ بێت. ئەنجامەکە exception بوو. ئێستا تۆمارکردن ٨ پیت دەوێت. چوونەژوورەوە بۆ بەکارهێنەرە کۆنەکان هیچ سنووری درێژی نییە.
- **ئەدانەکانی تر:** `AdhanService` دەیویست `adhan_fajr.mp3`، `adhan_makkah.mp3` و هتد لێبدات، بەڵام تەنها `adhan_default.mp3` هەیە. ئێستا ئەگەر فایلەکە نەبوو، ئەدانی ئاسایی لێدەدرێت.
- **وەشانی پاکێج:** لە `pubspec` دا وەشانی `supabase_flutter` بۆ `^2.15.4` بەرزکرایەوە، چونکە `main.dart` پارامەتری `publishableKey` بەکاردێنێت. هەروەها Flutter بۆ `>=3.27`، چونکە کۆدەکە `withValues()` بەکاردێنێت.
- **`env.dart`:** لە وەشانی release دا هیچ شتێک چاپ نابێت.

## 🟡 پاکێجەکان

- `audioplayers` گۆڕدرا بۆ `just_audio` (`adhan_service.dart`، `prayer_times_screen.dart`).
- **لابران، چونکە هیچ فایلێک بەکاری نەدەهێنان:** `dio`، `bcrypt`، `crypto`، `flutter_svg`، `table_calendar`، `flutter_staggered_animations`، `file_picker`، `image_editor`، `speech_to_text`، `kelar_boundaries`.
- `excel` و `proj4dart` و `supabase` گواسترانەوە بۆ `dev_dependencies`، چونکە تەنها سکریپتەکانی `tool/` بەکاریان دەهێنن.
- دێڕی دووبارەی `adhan_default.mp3` لە assets لابرا.

## 🟡 فایلە سڕاوەکان

**٨ فایلی بەتاڵ (0 بایت):** `alarm_manager`، `prayer_times_service`، `base_pdf_service`، `dictionary_service`، `auth_signup_service`، `secure_storage_service`، `screens/gallery/admin_gallery`، `providers/theme_provider_test`

**تاقیکردنەوە کە لە ناو `lib/`ـدا بوون:** `services/password_hasher_test.dart`، `utils/password_hasher_test.dart`

**گواسترانەوە بۆ `unused_code/`:** ئەم ٢٨ فایلە هیچ شوێنێکی ئەپەکە بەکاری نەدەهێنان. نەسڕاونەتەوە، تەنها لە `lib/` دەرهێنراون. ئەگەر یەکێکیانت پێویستە، بیگەڕێنەرەوە:

`instructions_screen`، `currency_chart_screen`، `fuel_calculator_screen`، `admin_single_add_product`، `admin_currency`، `admin_fuel`، `app_drawer`، `custom_bottom_nav`، `live_users_badge`، `complaints_chart_widget`، `emergency_card`، `neighborhood_card`، `animated_widgets`، `loading_widget`، `cached_future_builder`، `app_text`، `dynamic_text`، `error_handler`، `error_reporter`، `label_marker_helper`، `map_style`، `event_reminder_service`، `fuel_favorites_service`، `news_service`، `price_alert_service`، `category_providers`، مۆدێلەکانی `fuel_price`/`fuel_price_history`/`fuel_station`/`emergency_contact`

---

## ℹ️ ئەوەی نەگۆڕدرا و بۆچی

- **شاشە ئامادەکراوەکان کە بەستراو نین:** هەڵسەنگاندن (`reviews/*`)، `prayer_settings_screen`، `notification_test_screen`، `neighborhoods_map_screen`، `store_services_screen`، `service_details_screen`. ئەم شاشانە دروستکراون و تاقیکردنەوەیان بۆ نووسراوە، بەڵام هیچ دوگمەیەک نایانکاتەوە. پێویستە بڕیار بدەیت: یان بیانبەستە بە ئەپەکەوە، یان بیانسڕەوە.
- **دابەشکردنی فایلە گەورەکان** (`admin_complaints` ٨٢KB، `admin_dashboard` ٧٦KB و هتد): بە بێ کۆمپایلەر مەترسیدارە. باشترە یەک بە یەک بیکەین، و دوای هەر دابەشکردنێک `flutter analyze` ڕابکەیت.
- **provider + riverpod:** گواستنەوەی ٤١ فایل لە provider بۆ riverpod کارێکی گەورەیە. ئێستا هەردووکیان کار دەکەن.
- **سیستەمی وەرگێڕان:** ئەپەکە `config/translations.dart` بەکاردێنێت. فایلەکانی `l10n/*.arb` هێشتا بەکارنەهاتوون. یەکخستنیان کارێکی جیایە.
- `use_build_context_synchronously`: بۆ دۆزینەوەی ئەم هەڵانە پێویستم بە ئەنجامی `flutter analyze` هەیە.

---

## 🔐 RLS — ڕۆڵەکان لەسەر سێرڤەر (`20261108_rls_lockdown.sql`)

> ⚠️ **ڕیزبەندی:** پێشتر backup بگرە، پاشان `20261107_secure_login.sql` و ئینجا `20261108_rls_lockdown.sql` ڕابکە. هەمان کات ئەپی نوێ بڵاو بکەرەوە.

**چۆن کار دەکات:** هەر ئەپێک بە شێوەی anonymous دەچێتە Supabase. کاتێک `app_login` سەرکەوتوو دەبێت، سێرڤەر لە خشتەی `app_sessions` تۆمار دەکات کە ئەم session ـە هی کام بەکارهێنەرە و ڕۆڵەکەی چییە. پاشان RLS لە سێرڤەرەوە بڕیار دەدات کێ چی بکات، نەک لە مۆبایلەوە.

| خشتە | خوێندنەوە | نووسین |
|---|---|---|
| هەواڵ، شوێن، نرخ، فەرمانگە، ڕووداو، بانەر… | هەمووان | ئەدمین، یان خاوەنی خۆی (ڤێندەر / فەرمانگە) |
| `complaints` | ئەدمین + ناردەری خۆی | ناردن: هەمووان · گۆڕین: ئەدمین |
| `app_users` | ئەدمین | ئەدمین (چوونەژوورەوە و تۆمارکردن بە RPC) |

**گۆڕانکاری ئەپ:** `app_current_user` لە جیاتی `get_user_for_login` · `app_logout` · `app_set_fcm_token` · بینین و لایک تەنها بە RPC · داواکاری ڤێندەری `vendor_pending` ئێستا لە پانێڵی ئەدمین دەردەکەوێت.

**دوای ڕاکردن:** ئەدمین، ڤێندەر و فەرمانگەکان دەبێت یەکجار دووبارە بچنە ژوورەوە.

**هێشتا نەگۆڕدراون:** `reviews`، `news_likes`، `news_favorites`، `favorite_stores`، `event_interests`، `active_users` و storage. ئەگەر trigger ێک هەیە کە لە کاتی review دا `dukan` نوێ دەکاتەوە، دەبێت `security definer` بێت.

---

## 🔐 RLS بۆ داتای تایبەتی بەکارهێنەر (`20261109_rls_user_tables.sql`)

دوای `20261108_rls_lockdown.sql` ڕای بکە.

- لایک، دڵخوازەکان و "حەزم لێیە" ی ڕووداوەکان: تەنها خاوەنەکەی (و ئەدمین) دەیبینێت و دەیگۆڕێت.
- Review: ئەوانەی پەسەند کراون بۆ هەمووان دیارن. نووسەر review ی خۆی دەگۆڕێت، ئەدمین هەمووی بەڕێوە دەبات.
- trigger ـەکانی `reviews` دەگۆڕدرێن بۆ `security definer`، بۆ ئەوەی نمرەی شوێنەکان هەر نوێ ببێتەوە.

## ✅ کوالیتی

- `flutter analyze --fatal-infos`: **0 کێشە** (پێشتر ١٠٦).
- `flutter test`: **84 تێست**، هەمووی سەرکەوتوو.
- `supabase/tests/run.sh`: **49 پشکنینی RLS** لەسەر Postgres ی ڕاستەقینە.
- GitHub Actions (`.github/workflows/ci.yml`) هەموو ئەمانە لە هەر push و PR ێکدا ڕادەکات.
- فایلە گەورەکان دابەش کران: بەشی ڕووکار لە فایلی `*_ui.dart` دایە.

---

## 🕌 کاتەکانی نوێژ — گۆڕانکاری ئەدمین (`20261110_prayer_times.sql`)

دوای `20261108_rls_lockdown.sql` ڕای بکە. خشتەی `prayer_times_official` دروست دەکات (هەمووان دەخوێننەوە، تەنها ئەدمین دەنووسێت).

- **پانێڵی ئەدمین ← کاتەکانی نوێژ:** دەستکاری ڕۆژێک، یان پەیستکردنی مانگێکی تەواو وەک ئامۆژگاری (`7 05:05 06:30 11:47 02:37 05:04 06:15`). پەنجە ڕاگرتن لەسەر ڕۆژێک = گەڕانەوە بۆ کاتی ئەپ.
- ڕیزبەندی: گۆڕانکاری ئەدمین ← خشتەی ناو ئەپ (`lib/data/kalar_prayer_times.dart`) ← هەژمار.
- کلیلی ڕۆژ `dd-MM` ـە (بێ ساڵ)، بۆیە یەک خشتە بۆ هەموو ساڵەکان کار دەکات.

---

## 🌍 فرەزمانی تەواو (کوردی / عەرەبی / ئینگلیزی)

پێشتر نزیکەی ٢٢٠٠ دەقی کوردی ڕاستەوخۆ لە ناو کۆددا نووسرابوون، بۆیە لە زۆربەی شاشەکاندا گۆڕینی زمان کاری نەدەکرد.

- **`lib/l10n/tr.dart`:** `tr('دەقی کوردی')` و `trf('{0} خولەک', [n])`. دەقی کوردی خۆی کلیلەکەیە.
- **وەرگێڕانەکان:** `lib/l10n/strings/strings_en.dart` و `strings_ar.dart` (١٦٠٠+ دەق).
- **ئاراستە:** ئینگلیزی چەپ-بۆ-ڕاستە، کوردی و عەرەبی ڕاست-بۆ-چەپ.
- **گۆڕینی زمان:** یەکسەر هەموو شاشە کراوەکان دەگۆڕێت، بێ ئەوەی ئەپەکە دابخرێت.
- **داتای داتابەیس** (ناوی بەش و شوێن): `AutoTranslate` یەکەم جار خشتەی ناو ئەپ دەپشکنێت، ئەگەر نەبوو بە Gemini وەری دەگێڕێت، و ئەنجامەکە لەسەر مۆبایل هەڵدەگیرێت.
  ⚠️ پێویستە فەنکشنی نوێ بڵاو بکەیتەوە: `supabase functions deploy translate-text` (هەمان `GEMINI_API_KEY` ی `gemini-proxy` بەکاردێنێت).
- **کاتی نوێژ:** `AM/PM` بۆ ئینگلیزی، `ص/م` بۆ عەرەبی.

**تێست:**
- `test/l10n/translations_test.dart`: هەموو `tr()` ـێک وەرگێڕانی هەیە و `{0}` ـەکان ڕێکن.
- `test/l10n/screens_english_test.dart`: ٢٢ شاشە بە هەر ٣ زمان دەکرێنەوە و پشکنین دەکرێت کە هیچ پیتێکی کوردی لە ئینگلیزی و عەرەبیدا نەماوە.

**دەقی نوێ زیاد دەکەیت؟** بە `tr('...')` بینووسە و وەرگێڕانەکەی لە هەردوو فایلی `strings_*.dart` زیاد بکە. ئەگەر لەبیرت چوو، CI پێت دەڵێت.

**هێشتا کوردین:** ڕاپۆرتەکانی PDF ی ئەدمین، و ئەو ڕێنماییانەی بۆ Gemini دەنێردرێن، کە بە ئەنقەست کوردی ماونەتەوە.
