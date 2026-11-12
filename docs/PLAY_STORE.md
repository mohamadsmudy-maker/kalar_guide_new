# 📦 بڵاوکردنەوەی ئەپ لە Google Play — ڕێنمایی هەنگاو بە هەنگاو

> ئەمە ڕێنماییەکی کردارییە، نەک ڕاوێژی یاسایی. پێش ناردن، وەڵامەکانی فۆرمەکان بە سیاسەتەکەی ئەپ
> (`docs/privacy-policy.html`) بەراورد بکە.

## ٠) پێش دەستپێکردن (زۆر گرنگ)

- [ ] **keystore** (`.jks`) و `android/key.properties` و پاسۆردەکان لە دوو شوێنی سەلامەت کۆپی بکە.
      ئەگەر ون ببن، ناتوانیت ئەپەکە نوێ بکەیتەوە. هەرگیز لە git دا نابن و بۆ کەسیش مەینێرە.
- [ ] کلیلی Google ی دەرچوو (`AIzaSyDSB1…`) **Rotate** بکە و کلیلە نوێیەکە لە `android/local.properties` بنووسە.
- [ ] `pubspec.yaml`: `version: 1.1.0+2` — پاش `+` ژمارەی build ـە. **هەر ناردنێکی نوێ دەبێت ژمارەکەی زیاد بکەیت**
      (`+3`، `+4`...).
- [ ] APK ی release لەسەر دوو سێ مۆبایل تاقی بکەوە (چوونەژوورەوە، نەخشە، سکاڵا، ئاگاداری).

## ١) دروستکردنی فایلی AAB

Play تەنها **`.aab`** وەردەگرێت (نەک APK). لە PowerShell:

```powershell
flutter pub get
flutter build appbundle --release `
  --obfuscate --split-debug-info=symbols\v1.1.0+2 `
  --dart-define=SUPABASE_URL=... `
  --dart-define=SUPABASE_ANON_KEY=... `
  --dart-define=GOOGLE_WEB_CLIENT_ID=...
```

فایلەکە لێرە دروست دەبێت: `build\app\outputs\bundle\release\app-release.aab`.
**پۆشەی `symbols\v1.1.0+2` هەڵبگرە** — بۆ خوێندنەوەی Crash ـەکان پێویستە (`flutter symbolize`).

## ٢) دروستکردنی ئەپ لە Play Console

1. هەژماری گەشەپێدەر (تێچوو: $25 یەکجار).
2. **Create app**: ناو «ڕێبەری کەلار»، زمانی سەرەکی، **App** (نەک Game)، **Free**.
3. **Play App Signing** چالاک بێت (بە بنەڕەت). keystore ی خۆت وەک «upload key» دەبێت.

## ٣) لاپەڕەی ئەپ (Store listing)

| شت | پێداویستی |
|---|---|
| ناوی ئەپ | ≤ 30 پیت |
| وەسفی کورت | ≤ 80 پیت |
| وەسفی تەواو | ≤ 4000 پیت |
| ئایکۆن | PNG ٥١٢×٥١٢ (لە `assets/branding/app_icon_1024.png` بچووکی بکەوە) |
| Feature graphic | ١٠٢٤×٥٠٠ |
| وێنەی شاشە | کەمتر نەبێت لە ٢ (٤-٨ باشە)، تاقیکردنەوە لەسەر مۆبایل |

## ٤) URL ەکان (Play دەیانخوازێت)

1. **سیاسەتی تایبەتمەندی:** GitHub ← Settings ← **Pages** ← Source `main` / `/docs`. دوای چەند خولەک:
   `https://mohamadsmudy-maker.github.io/kalar_guide_new/privacy-policy.html`
2. **سڕینەوەی ئەکاونت:** هەمان شێوە:
   `https://mohamadsmudy-maker.github.io/kalar_guide_new/delete-account.html`
   (لە Play Console ← App content ← Data safety ← «Data deletion» دایبنێ.)

## ٥) App content

- **Privacy policy:** URL ی سەرەوە.
- **Ads:** نا (ڕیکلامی تێدا نییە).
- **App access:** ئەپەکە بەبێ ئەکاونت بەکاردێت. بەشی ئەدمین/ڤێندەر ئەکاونتی تاقیکردنەوە دەوێت — ئەگەر Play
  داوای کرد، ئەکاونتێکی تاقیکردنەوەی **ڤێندەر** (نەک ئەدمین) بدە.
- **Content rating:** پرسیارنامەکە پڕ بکەوە (ناوەڕۆکی توندوتیژی/ئەنجامی نییە).
- **Target audience:** **١٨+** یان «هەموو» — ئەپەکە بۆ منداڵان نییە، بۆیە «Designed for children» هەڵمەبژێرە.
- **Government apps:** ئەگەر ئەپەکە بە ناوی لایەنێکی حکومییەوە دەبێت، Play بەڵگە دەخوازێت. ئەگەر ئەپی خۆبەخش
  یان لایەنی سێیەمە، بنووسە و «فەرمی» نەڵێ.

## ٦) Data safety (بە بنەمای سیاسەتەکەی ئەپ)

| جۆری داتا | کۆدەکرێتەوە؟ | بۆچی | هاوبەش دەکرێت؟ |
|---|---|---|---|
| ناو، ئیمەیڵ، ژمارەی مۆبایل | بەڵێ | ئەکاونت | نا (تەنها Supabase وەک خزمەتگوزاری) |
| شوێن (GPS)، تەنها دوای ڕێگەپێدان | بەڵێ (کاتی سکاڵا) | نەخشە، سکاڵا | نا |
| وێنە و دەنگ | بەڵێ (کاتی سکاڵا) | ناردنی سکاڵا | بۆ فەرمانگەی بەرپرس |
| چالاکی (دڵخواز، لایک، هەڵسەنگاندن) | بەڵێ | ئەزموونی ئەپ | نا |
| ناسنامەی ئامێر / FCM token | بەڵێ | ئاگاداری، ئامار | نا (Firebase وەک خزمەتگوزاری) |
| Crash و کارایی | بەڵێ | Firebase Crashlytics/Analytics | نا |

- **Encrypted in transit:** بەڵێ (HTTPS).
- **Users can request deletion:** بەڵێ (لەناو ئەپ + URL ی سەرەوە).
- ئەمە ڕاستی خۆت دەبێت بەرانبەر ئەو کۆدە کە بەڕاستی دەیکات. ئەگەر شتێکی نوێ زیاد کرد، فۆرمەکە نوێ بکەوە.

## ٧) مۆڵەتەکانی ئەندرۆید (Play ڕەخنەیان لێ دەگرێت)

| مۆڵەت | بۆچی | تێبینی |
|---|---|---|
| `ACCESS_FINE/COARSE_LOCATION` | نزیکترین شوێن، سکاڵا | تەنها کاتی بەکارهێنان (foreground) |
| `RECORD_AUDIO` | تۆماری دەنگی سکاڵا | لە Data safety بنووسە |
| `POST_NOTIFICATIONS` | ئاگاداری | |
| `SCHEDULE_EXACT_ALARM` | بانگ/کاتی نوێژ | Play بۆ ئەم مۆڵەتە ڕوونکردنەوە دەخوازێت؛ بنووسە «ئاگاداری کاتی نوێژ» |
| `WRITE_EXTERNAL_STORAGE` | — | **لابراوە بۆ ئەندرۆید ١٠+** (`maxSdkVersion=28`) |

## ٨) یەکەم بڵاوکردنەوە

1. **Internal testing** ← AAB بنێرە ← ٢-٣ کەس تاقی بکەنەوە (تێچوو نییە، پێداچوونەوەی خێرا).
2. پاشان **Closed testing**. ئەگەر هەژمارەکەت تازەیە، Play ڕەنگە داوا بکات ≥ ١٢ تاقیکەر بۆ ١٤ ڕۆژ پێش Production.
3. **Production** ← Create release ← AAB ← Release notes ← Review.
4. پێداچوونەوەکە چەند ڕۆژ دەخایەنێت.

## ٩) دوای بڵاوکردنەوە

- Crashlytics و Play Console ← **Android vitals** بپشکنە.
- پاشەکەوتی داتابەیسی Supabase هەفتانە export بکە.
- هەر نوێکردنەوەیەک: ژمارەی `+` زیاد بکە، AAB نوێ، symbols ی نوێ هەڵبگرە.
