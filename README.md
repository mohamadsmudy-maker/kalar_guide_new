# 🏙️ ڕێبەری کەلار — Kalar Guide

> **ئەپی فەرمی شاری کەلار** — ڕێبەرێکی گشتگیر بۆ هاوڵاتیان

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-blue.svg)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-green.svg)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📖 دەربارە

**ڕێبەری کەلار** ئەپێکی فەرمییە بۆ شاری کەلار لە هەرێمی کوردستان. ئەم ئەپە خزمەتگوزارییەکانی وەک دۆزینەوەی شوێنەکان، بینینی هەواڵەکان، نرخی دراو و سووتەمەنی، ناردنی سکاڵا، کەشوهەوا، و چەندین تایبەتمەندی تر پێشکەش دەکات.

---

## ✨ تایبەتمەندییەکان

### 🎯 بۆ هاوڵاتیان
- 🏪 **شوێنەکان** — دۆزینەوەی شوێن لەسەر نەخشە و لیست
- 📰 **هەواڵەکان** — دوایین هەواڵ و ئاگادارییەکان
- 💱 **نرخی دراو** — دۆلار، دینار، زێڕ
- ⛽ **نرخی سووتەمەنی** — بەنزین و گاز
- 📝 **سکاڵا** — ناردنی سکاڵا بە وێنە، دەنگ، و لۆکەیشن
- 🌤️ **کەشوهەوا** — دۆخی ئێستا
- 🕌 **کاتەکانی نوێژ** — بەپێی شوێن
- 🧭 **قیبلە** — ئاراستەی کەعبە
- 📚 **ڕێنماییەکان** — مامەڵەکانی فەرمانگەکان

### 🔧 بۆ ئەدمین
- 👑 **پانێڵی بەڕێوەبردن** — بەڕێوەبردنی هەموو بەشەکان
- 📊 **ڕاپۆرت** — ڕاپۆرتی PDF و چارت
- 🤖 **AI Chat** — شیکردنەوەی داتا
- 👥 **بەڕێوەبردنی بەکارهێنەران**

### 🌍 فرەزمانی
- 🇮🇶 کوردی (Sorani)
- 🇸🇦 عەرەبی
- 🇬🇧 ئینگلیزی

---

## 🚀 دەستپێکردن

### 📋 پێداویستییەکان

- Flutter **3.24+**
- Dart **3.5+**
- Android Studio / VS Code
- Supabase Account
- Firebase Project

### 🔧 دامەزراندن

```bash
# ١. کۆپی پرۆژە
git clone https://github.com/mohamadsmudy-maker/kalar_guide_new.git
cd kalar_guide_new

# ٢. دامەزراندنی پاکێجەکان (Flutter 3.44+)
flutter pub get
```

### 🔐 کلیلەکانی Supabase

ئەپەکە فایلی `.env` ناخوێنێتەوە. کلیلەکان لە کاتی build دا بە `--dart-define` دەدرێن
(بڕوانە `lib/config/env.dart`). بەبێ ئەوان ئەپەکە ناتوانێت پەیوەندی بە Supabase ەوە بکات.

```
--dart-define=SUPABASE_URL=https://<project-ref>.supabase.co
--dart-define=SUPABASE_ANON_KEY=<anon key>
```

**Android Studio:** Run ← Edit Configurations… ← `main.dart` ← **Additional run args** ← هەردوو دێڕەکەی سەرەوە (بە یەک دێڕ، بۆشایی لە نێوانیان).

### ▶️ جێبەجێکردن

```bash
# Debug (مۆبایلی پەیوەستکراو)
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Release APK — یان لە Windows: ./build_release.ps1
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=symbols/v1 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# بۆ Play Store
flutter build appbundle --release --obfuscate --split-debug-info=symbols/v1 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

بۆ ئیمزاکردنی Release، `android/key.properties` و فایلی keystore پێویستن (لە git دا نین).

> **Obfuscation:** `--obfuscate` ناوی کلاس و فەنکشنەکان دەشارێتەوە. فایلەکانی `symbols/<وەشان>` (لە git دا نین) هەڵبگرە — بۆ خوێندنەوەی Crash ـەکان پێویستن (`flutter symbolize`). دەقەکان (URL، کلیلی anon) هەر دەردەکەون، بۆیە هیچ نهێنییەک نەخەیتە ناو ئەپەکە.

---

## 📁 پێکهاتەی پرۆژە

```
lib/
├── core/                          # بنەڕەتی
│   ├── base/                      # Base Classes
│   ├── constants/                 # نرخی جێگیر
│   ├── errors/                    # جۆرەکانی هەڵە
│   ├── extensions/                # Dart Extensions
│   └── utils/                     # ئامرازەکان
│
├── config/                        # ڕێکخستن
│   ├── app_colors.dart
│   ├── constants.dart
│   ├── settings_provider.dart
│   ├── theme.dart
│   ├── theme_provider.dart
│   └── translations.dart
│
├── data/                          # داتا
│   ├── models/                    # مۆدێلەکان
│   └── repositories/              # Repositories
│
├── features/                      # تایبەتمەندییەکان
│   ├── admin/                     # ئەدمین
│   ├── complaints/                # سکاڵاکان
│   ├── currency/                  # دراو
│   ├── favorites/                 # دڵخوازەکان
│   ├── fuel/                      # سووتەمەنی
│   ├── home/                      # شاشەی سەرەکی
│   ├── news/                      # هەواڵەکان
│   ├── orders/                    # داواکارییەکان
│   ├── products/                  # کاڵاکان
│   ├── profile/                   # پرۆفایل
│   ├── stores/                    # شوێنەکان
│   └── ...
│
├── services/                      # خزمەتگوزارییەکان
│   ├── ai_service.dart
│   ├── auth_service.dart
│   ├── cache_service.dart
│   ├── currency_service.dart
│   ├── fuel_service.dart
│   ├── image_service.dart
│   ├── location_service.dart
│   ├── notification_service.dart
│   ├── storage_service.dart
│   └── translation_service.dart
│
├── widgets/                       # Widgets ی گشتی
│   ├── cards/
│   ├── carousels/
│   ├── common/
│   └── ultra_pro/
│
└── main.dart                      # خاڵی دەستپێک
```

---

## 🏗️ بناسازی

ئەم پرۆژە پشت دەبەستێت بە:

| بەش | تەکنەلۆژی |
|-----|----------|
| **Frontend** | Flutter + Dart |
| **Backend** | Supabase (PostgreSQL) |
| **AI** | Google Gemini |
| **Maps** | Google Maps Flutter |
| **Notifications** | Firebase Cloud Messaging |
| **State** | Provider + ChangeNotifier |
| **Storage** | Supabase Storage |
| **Cache** | SharedPreferences + Memory |

---

## 🧪 تاقیکردنەوە

```bash
# هەموو test
flutter test

# Test ی تایبەت
flutter test test/core/

# Coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## 🎨 ڕەنگ و دیزاین

| ڕەنگ | کۆد | بەکارهێنان |
|------|------|----------|
| 🔵 شین | `#1E88E5` | ڕەنگی سەرەکی |
| 🟣 مۆر | `#6C5CE7` | ڕەنگی دووەم |
| 🟢 سەوز | `#10B981` | سەرکەوتوو |
| 🔴 سوور | `#EF4444` | هەڵە |
| 🟠 نارنجی | `#F59E0B` | ئاگاداری |

---

## 🤝 بەشداریکردن

بەشداریت پێویستە! تکایە:

1. **Fork** بکە
2. **Branch** ی نوێ دروست بکە (`git checkout -b feature/amazing`)
3. **Commit** بکە (`git commit -m 'Add amazing feature'`)
4. **Push** بکە (`git push origin feature/amazing`)
5. **Pull Request** بکە

---

## 📞 پەیوەندی

- 📧 ئیمەیڵ: [your-email@example.com]
- 💬 واتسئاپ: [+964 xxx xxx xxxx]
- 📘 فەیسبووک: [facebook.com/kalarguide]
- 🌐 ماڵپەڕ: [kalarguide.com]

---

## 📄 مۆڵەت

ئەم پرۆژە بە مۆڵەتی **MIT** بڵاوکراوەتەوە — بۆ زانیاری زیاتر بڕوانە [LICENSE](LICENSE).

---

## 🙏 سوپاس

سوپاس بۆ هەموو ئەوانەی یارمەتیان دا لەم پرۆژە:

- 👨‍💻 هەموو گەشەپێدەران
- 🏙️ خەڵکی شاری کەلار
- 💙 هەموو بەکارهێنەران

---

<div align="center">

**بە خۆشەویستی دروستکراوە بۆ خەڵکی کەلار ❤️**

[⬆ بگەڕێوە بۆ سەرەوە](#-ڕێبەری-کەلار--kalar-guide)

</div>