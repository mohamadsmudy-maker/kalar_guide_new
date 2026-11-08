# 🔵 چوونەژوورەوە بە Google — ڕێنمایی ڕێکخستن

چوونەژوورەوە بە Google **بەخۆڕاییە** و پێویستی بە SMS نییە (ئیمەیڵەکە Google
خۆی پشتڕاستی کردووەتەوە). کۆدەکە ئامادەیە؛ تەنها ئەم ڕێکخستنانە ماون.
تا تەواو نەبن، دوگمەی Google لە ئەپەکەدا **پیشان نادرێت** و چوونەژوورەوەی
مۆبایل + پاسۆرد وەک خۆی کار دەکات.

> کات: نزیکەی ١٠–١٥ خولەک.  ناوی پاکێجی ئەپ: `com.muhammad.kalar.kalar_guide`

---

## ١) SHA-1 ی ئەپەکە وەربگرە

لە Android Studio → Terminal:

```powershell
cd android
./gradlew signingReport
```

لە ئەنجامەکەدا بۆ `Variant: debug` و `Variant: release` دێڕی **SHA1** کۆپی بکە.

> ئەگەر ئەپەکە لە Google Play بڵاو دەکەیتەوە: Play Console → ئەپەکەت →
> **Setup → App signing** → SHA-1 ی **App signing key** ـیش کۆپی بکە.
> بەبێ ئەمە Google لە وەشانی Play دا کار ناکات.

## ٢) Firebase — SHA-1 زیاد بکە

1. <https://console.firebase.google.com> → پرۆژەکەت → ⚙️ **Project settings**
2. **Your apps** → ئەپی Android (`com.muhammad.kalar.kalar_guide`)
3. **Add fingerprint** → هەموو SHA-1 ەکانی هەنگاوی ١ زیاد بکە
4. `google-services.json` ی نوێ دابگرە و لە جیاتی
   `android/app/google-services.json` دایبنێ

## ٣) Google Cloud — Web client ID و Secret

1. <https://console.cloud.google.com> → هەمان پرۆژەی Firebase
2. **APIs & Services → OAuth consent screen**: ئەگەر ڕێکنەخراوە، **External**
   هەڵبژێرە، ناوی ئەپ «ڕێبەری کەلار» و ئیمەیڵی خۆت بنووسە → **Publish app**
3. **APIs & Services → Credentials** → لە **OAuth 2.0 Client IDs** دا
   «**Web client (auto created by Google Service)**» بکەرەوە
   - **Client ID** کۆپی بکە (کۆتایی بە `.apps.googleusercontent.com` دێت)
   - **Client secret** کۆپی بکە
   > ئەگەر نەبوو: **Create credentials → OAuth client ID → Web application**

## ٤) Supabase — Google چالاک بکە

1. Supabase → **Authentication → Sign In / Providers → Google** → **Enable**
2. **Client IDs**: Web client ID ی هەنگاوی ٣
3. **Client Secret**: Client secret ی هەنگاوی ٣
4. **Save**
5. **SQL Editor** → ئەم فایلە جێبەجێ بکە:
   `supabase/migrations/20261113_google_login.sql`

## ٥) Web client ID بدە بە ئەپەکە

- **بۆ release:** لە `build_release.ps1` دا:
  ```powershell
  $GOOGLE_WEB_CLIENT_ID = "123...apps.googleusercontent.com"
  ```
- **بۆ Run لە Android Studio:** Run → Edit Configurations → **Additional run args**:
  ```
  --dart-define=GOOGLE_WEB_CLIENT_ID=123...apps.googleusercontent.com
  ```
  (لەگەڵ `SUPABASE_URL` و `SUPABASE_ANON_KEY` ی ئێستا)

> Web client ID نهێنی نییە؛ دەتوانرێت لە کۆدەکەدا بێت. **Client secret** نهێنییە —
> تەنها لە Supabase دا دایبنێ، هەرگیز لە ئەپەکەدا مەینووسە.

---

## چۆن کار دەکات

| بەکارهێنەر | چوونەژوورەوە |
|---|---|
| هاوڵاتی | Google (یان مۆبایل + پاسۆرد) |
| خاوەن شوێن، ئەدمین | مۆبایل + پاسۆرد (وەک پێشوو) |

- یەکەم جار کە کەسێک بە Google دێتە ژوورەوە، ئەکاونتێکی **بەکارهێنەر**ی بۆ
  دروست دەکرێت (`app_users.email`). جاری دواتر هەمان ئەکاونت دەدۆزرێتەوە.
- **ئەدمین یان خاوەن شوێن** دەتوانن Google بەکاربهێنن: لە Supabase → Table
  Editor → `app_users` ئیمەیڵی Gmail ـەکەیان لە ستوونی `email` بنووسە. ئیتر
  بە Google دێنە ژوورەوە بە هەمان ڕۆڵ.
- **سڕینەوەی ئەکاونت** لە پرۆفایلدایە (Google Play داوای دەکات). ئەدمین
  ناتوانێت ئەکاونتی خۆی بسڕێتەوە.

## کێشەکان

| هەڵە | چارەسەر |
|---|---|
| «چوونەژوورەوە بە Google سەرکەوتوو نەبوو» دەستبەجێ | SHA-1 ی ئەو وەشانە لە Firebase نییە (هەنگاوی ١–٢) |
| لە Play کار ناکات، لە Android Studio کار دەکات | SHA-1 ی **App signing key** ی Play زیاد بکە |
| «سێرڤەر ئەکاونتەکەی وەرنەگرت» | SQL ی هەنگاوی ٤.٥ جێبەجێ نەکراوە، یان Google لە Supabase چالاک نییە |
| هەڵەی `nonce` لە لۆگی Supabase | Supabase → Google → **Skip nonce checks** چالاک بکە |
