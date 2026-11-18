# 🔒 وەڵامەکانی Play Console ← App content

ئەم وەڵامانە لە سەر بنەمای کۆدی ئێستای ئەپەکە نووسراون (نوێمبەری ٢٠٢٦).
ئەگەر تایبەتمەندییەکی نوێ زیاد کرا کە داتای نوێ کۆدەکاتەوە، ئەم فایلە نوێ بکەرەوە.
پرسیار و ناوی دوگمەکان لە Play Console بە ئینگلیزین، بۆیە بە ئینگلیزی نووسراون.

---

## ١) Privacy policy
لینکی گشتیی `docs/privacy-policy.html` (بۆ نموونە GitHub Pages).

## ٢) Ads
**Does your app contain ads?** → **No**

## ٣) App access
هەموو بەشەکان بێ چوونەژوورەوە کار دەکەن، جگە لە پانێڵی ئەدمین و ڤێندەر.
- **All or some functionality is restricted** هەڵبژێرە.
- هەژمارێکی **تاقیکاری** (نەک هەژماری خۆت) بۆ Google دروست بکە، کە ڕۆڵی customer ـی هەبێت، و ژمارە و پاسۆردەکەی لێرە بنووسە.
  پانێڵی ئەدمین پێویست نییە پیشانی بدەیت.

## ٤) Content rating
پرسیارنامەکە بە ڕاستی پڕ بکەرەوە. خاڵە گرنگەکان:
- Category: **Reference, News, or Educational**، یان ئەوەی نزیکترە.
- **Users can interact / share content?** → **Yes**، چونکە هەڵسەنگاندن (reviews) و پێشنیاری شوێن هەن.
- **Shares user location with other users?** → **No**.
- توندوتیژی، سێکس، قومار و ماددەی هۆشبەر: **No**.

### ناوەڕۆکی بەکارهێنەران (UGC)
- هەر کۆمێنتێک دوگمەی 🚩 **ڕاپۆرتکردن** ـی هەیە، و میوانیش دەتوانن ڕاپۆرت بکەن.
- کاتێک ٣ کەسی جیاواز هەمان کۆمێنت ڕاپۆرت دەکەن، خۆکار دەشاردرێتەوە.
- ئەدمین لە **کۆمێنتە ڕاپۆرتکراوەکان** دەیسڕێتەوە یان دەیهێڵێتەوە.
- پێش ناردنی کۆمێنت، یاساکان پیشان دەدرێن (جنێو، ڕیکلام، درۆ و زانیاریی کەسی قەدەغەن).
- ئەگەر Play پرسیاری کرد، بنووسە: «Users can report any review in-app; admins review reports and remove violating content; reviews reported by 3 users are hidden automatically».
- **مایگرەیشنی ٢٥** (`20261201_review_reports.sql`) پێش بارکردن پێویستە.

## ٥) Target audience
- **13–15، 16–17، 18+** هەڵبژێرە.
- **خوار ١٣ ساڵ هەڵمەبژێرە.** ئەگەر هەڵیبژێریت، یاسای Families ـی Google دەگرێتەوە و مەرجی زۆر زیاتر هەیە.

## ٦) News app
**Is your app a news app?** → **No**.
ئامانجی سەرەکیی ئەپەکە ڕێبەری شارە؛ هەواڵ تەنها بەشێکە.

## ٧) Government apps
ئەپەکە **فەرمیی حکومەت نییە**. لە ناو، وەسف و وێنەکاندا نابێت وا دەربکەوێت کە ئەپی فەرمیی شارەوانی یان حکومەتە.
ئەم ڕستەیە لە شاشەی «دەربارە» و لە کۆتایی وەسفی Play (هەر سێ زمانەکە) هەیە.
ئەگەر ڕۆژێک بوو بە ئەپی فەرمی، Play بەڵگەنامەی فەرمی دەوێت.

## ٨) Advertising ID
**Does your app use advertising ID?** → **No**
(لە `AndroidManifest.xml` مۆڵەتی `AD_ID` لابراوە و Analytics ناسنامەی ڕیکلام کۆناکاتەوە.)

## ٩) Permissions
- **شوێن:** تەنها کاتێک ئەپەکە کراوەیە (foreground) بەکاردێت، بۆیە فۆرمی background location پێویست نییە.
- **Exact alarm (`SCHEDULE_EXACT_ALARM`):** بۆ بانگ بەکاردێت، و بەکارهێنەر خۆی ڕێگەی پێدەدات.
  ئەگەر Play پرسیاری کرد، بنووسە: «Prayer-time (adhan) alarms at exact times, enabled by the user».

---

## ١٠) Data safety

### بەشی یەکەم
| پرسیار | وەڵام |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (هەمووی HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** |
| Delete account URL | لینکی گشتیی `docs/delete-account.html` |

### بەشی دووەم: جۆرەکانی داتا
بۆ هەموویان **Shared = No** هەڵبژێرە. Supabase و Firebase «service provider» ن، و Google ئەوانە بە هاوبەشکردن (sharing) دانانێت.
ناردنی سکاڵا بە WhatsApp بە کرداری بەکارهێنەر خۆی دەکرێت، بۆیە ئەویش هاوبەشکردن نییە.

| بەش | جۆر | Collected | Required / Optional | مەبەست (Purposes) |
|---|---|---|---|---|
| **Location** | Precise location | ✅ | Optional | App functionality (شوێنی سکاڵا) |
| **Personal info** | Name | ✅ | Optional | App functionality, Account management |
| | Email address | ✅ | Optional | Account management (چوونەژوورەوە بە Google) |
| | Phone number | ✅ | Optional | Account management |
| | User IDs | ✅ | Optional | App functionality, Account management, Analytics |
| **Photos and videos** | Photos | ✅ | Optional | App functionality (وێنەی سکاڵا و شوێن) |
| **Audio** | Voice or sound recordings | ✅ | Optional | App functionality (دەنگی سکاڵا) |
| **App activity** | App interactions | ✅ | Optional | App functionality, Analytics (لایک، دڵخواز، بینین) |
| | In-app search history | ✅ | Optional | Analytics (بێ ناو و بێ ناسنامە) |
| | Other user-generated content | ✅ | Optional | App functionality (دەقی سکاڵا، هەڵسەنگاندن، پێشنیار) |
| **App info and performance** | Crash logs | ✅ | Required | Analytics (Crashlytics) |
| | Diagnostics | ✅ | Required | Analytics |
| **Device or other IDs** | Device or other IDs | ✅ | Required | App functionality (ئاگاداری)، Analytics |

**مەیکە ✅:** Financial info، Health، Messages، Contacts، Calendar، Files and docs، Web browsing.

### پرسیارەکانی هەر جۆرێک
- **Is this data processed ephemerally?** → **No**
- **Is this data required or optional?** → وەک خشتەکە.
  ئەپەکە بێ هەژماریش کار دەکات، بۆیە زانیاریی هەژمار Optional ـە.

> ⚠️ ئەگەر دواتر ڕیکلام، پارەدان یان شتێکی نوێ زیاد کرا، ئەم فۆرمە و سیاسەتی تایبەتمەندی دەبێت پێکەوە نوێ بکرێنەوە.
