#!/usr/bin/env python3
"""Generates the privacy policy (ku/ar/en) for the app and for the web.

Edit the text below, then run:  python3 tool/privacy_policy.py
Outputs:
  lib/l10n/privacy_policy_text.dart   (in-app screen)
  docs/privacy-policy.html            (host it and put the URL in Google Play)
"""
import html, json, os

UPDATED = '2026-11-08'
CONTACT_NAME = {'ku': 'محمد احمد محمد', 'ar': 'محمد احمد محمد', 'en': 'Mohammed Ahmed Mohammed'}
CONTACT_PHONE = '+964 770 157 4997'

POLICY = {
 'ku': {
  'title': 'سیاسەتی تایبەتمەندی',
  'app': 'ڕێبەری کەلار',
  'updated': 'دوایین نوێکردنەوە',
  'intro': 'ئەم سیاسەتە ڕوون دەکاتەوە کە ئەپی «ڕێبەری کەلار» چ زانیارییەک کۆدەکاتەوە، بۆچی، و چۆن دەتوانیت کۆنترۆڵی بکەیت. ئەپەکە بەبێ ئەکاونتیش بەکاردێت.',
  'sections': [
   ('ئەو زانیارییانەی کۆدەکرێنەوە', [
     'ئەکاونت: ناو، ژمارەی مۆبایل و پاسۆرد (پاسۆرد بە شێوەی هاش هەڵدەگیرێت و کەس نایبینێت)؛ یان ناو و ئیمەیڵ ئەگەر بە Google بچیتە ژوورەوە.',
     'شوێن (GPS): تەنها کاتێک ڕێگە دەدەیت — بۆ نزیکترین شوێن، نەخشە، قیبلە و کاتی نوێژ لەسەر مۆبایلەکەت بەکاردێت و نانێردرێت. تەنها کاتێک سکاڵایەک دەنێریت، شوێنی سکاڵاکە لەگەڵیدا دەنێردرێت.',
     'سکاڵا: دەق، وێنە و تۆماری دەنگ کە خۆت زیادیان دەکەیت.',
     'چالاکی: شوێنە دڵخوازەکان، لایک، هەڵسەنگاندن و ئەو شوێنانەی پێشنیاریان دەکەیت.',
     'ئاگاداری: کۆدێکی ئاگاداری (FCM token) بۆ ناردنی ئاگاداری.',
     'ئامار و هەڵە: ناسنامەیەکی هەڕەمەکی ئامێر، زمان و وەشانی ئەپ بۆ ژماردنی بەکارهێنەرانی چالاک؛ ئامار و ڕاپۆرتی کڕاش لە ڕێگەی Firebase بۆ باشترکردنی ئەپەکە.',
   ]),
   ('بۆچی بەکاردێن', [
     'بۆ پیشاندانی شوێن، هەواڵ، نرخ و خزمەتگوزارییەکانی کەلار.',
     'بۆ گەیاندنی سکاڵاکەت بە لایەنی پەیوەندیدار و ئاگادارکردنەوەت لە دۆخەکەی.',
     'بۆ پاراستنی ئەکاونتەکەت و ڕێگرتن لە بەکارهێنانی خراپ.',
     'هەرگیز زانیارییەکانت نافرۆشرێن و بۆ ڕیکلام بەکارنایەن.',
   ]),
   ('لەگەڵ کێ هاوبەش دەکرێن', [
     'Supabase: هەڵگرتنی داتا و چوونەژوورەوە.',
     'Google (Firebase، Google Sign-In، Google Maps، Gemini): ئاگاداری، ئامار، کڕاش، نەخشە و وەرگێڕانی ناوەڕۆکی گشتی (ناوی شوێن و هەواڵ — نەک زانیاری کەسی).',
     'سکاڵاکان: بۆ ئەو فەرمانگەیەی کە بەرپرسە دەنێردرێن.',
   ]),
   ('ماوەی هەڵگرتن و سڕینەوە', [
     'زانیارییەکان تا کاتێک ئەکاونتەکەت هەیە هەڵدەگیرێن.',
     'دەتوانیت هەر کاتێک لە پرۆفایل ← «سڕینەوەی ئەکاونت» ئەکاونتەکەت و دڵخواز، لایک و هەڵسەنگاندنەکانت بە یەکجاری بسڕیتەوە.',
     'سکاڵا نێردراوەکان وەک تۆماری فەرمی دەمێننەوە، بەڵام ئیتر بە ئەکاونتەکەتەوە نابەسترێنەوە.',
   ]),
   ('مافەکانت', [
     'دەتوانیت ڕێگەی شوێن و ئاگاداری لە ڕێکخستنەکانی مۆبایلەکەت دابخەیت.',
     'دەتوانیت داوای بینین، ڕاستکردنەوە یان سڕینەوەی زانیارییەکانت بکەیت.',
   ]),
   ('منداڵان', [
     'ئەپەکە بۆ هەمووانە، بەڵام بە ئەنقەست زانیاری منداڵانی خوار ١٣ ساڵ کۆناکاتەوە.',
   ]),
  ],
  'contact': 'پەیوەندی',
  'changes': 'ئەگەر ئەم سیاسەتە گۆڕا، بەرواری سەرەوە نوێ دەکرێتەوە.',
 },
 'ar': {
  'title': 'سياسة الخصوصية',
  'app': 'دليل كلار',
  'updated': 'آخر تحديث',
  'intro': 'توضح هذه السياسة المعلومات التي يجمعها تطبيق «دليل كلار»، ولماذا، وكيف يمكنك التحكم بها. يمكن استخدام التطبيق دون حساب أيضاً.',
  'sections': [
   ('المعلومات التي نجمعها', [
     'الحساب: الاسم ورقم الهاتف وكلمة المرور (تُحفظ مشفّرة ولا يراها أحد)؛ أو الاسم والبريد الإلكتروني عند تسجيل الدخول عبر Google.',
     'الموقع (GPS): فقط بإذنك — يُستخدم على هاتفك لإظهار أقرب الأماكن والخريطة والقبلة ومواقيت الصلاة ولا يُرسل. يُرسل موقع الشكوى فقط عندما ترسل شكوى.',
     'الشكاوى: النص والصور والتسجيلات الصوتية التي تضيفها بنفسك.',
     'النشاط: الأماكن المفضلة والإعجابات والتقييمات والأماكن التي تقترحها.',
     'الإشعارات: رمز الإشعارات (FCM token) لإرسال الإشعارات.',
     'الإحصاءات والأخطاء: معرّف عشوائي للجهاز واللغة وإصدار التطبيق لحساب المستخدمين النشطين؛ إحصاءات وتقارير الأعطال عبر Firebase لتحسين التطبيق.',
   ]),
   ('لماذا نستخدمها', [
     'لعرض أماكن كلار وأخبارها وأسعارها وخدماتها.',
     'لإيصال شكواك إلى الجهة المعنية وإبلاغك بحالتها.',
     'لحماية حسابك ومنع إساءة الاستخدام.',
     'لا نبيع معلوماتك أبداً ولا نستخدمها للإعلانات.',
   ]),
   ('مع من نشاركها', [
     'Supabase: تخزين البيانات وتسجيل الدخول.',
     'Google (Firebase وGoogle Sign-In وخرائط Google وGemini): الإشعارات والإحصاءات والأعطال والخرائط وترجمة المحتوى العام (أسماء الأماكن والأخبار — وليس المعلومات الشخصية).',
     'الشكاوى: تُرسل إلى الدائرة المسؤولة.',
   ]),
   ('مدة الاحتفاظ والحذف', [
     'نحتفظ بالمعلومات ما دام حسابك موجوداً.',
     'يمكنك في أي وقت من الملف الشخصي ← «حذف الحساب» حذف حسابك ومفضلاتك وإعجاباتك وتقييماتك نهائياً.',
     'تبقى الشكاوى المرسلة سجلاً رسمياً، لكنها لا تعود مرتبطة بحسابك.',
   ]),
   ('حقوقك', [
     'يمكنك إيقاف إذن الموقع والإشعارات من إعدادات هاتفك.',
     'يمكنك طلب الاطلاع على معلوماتك أو تصحيحها أو حذفها.',
   ]),
   ('الأطفال', [
     'التطبيق للجميع، لكنه لا يجمع عمداً معلومات الأطفال دون 13 عاماً.',
   ]),
  ],
  'contact': 'التواصل',
  'changes': 'إذا تغيّرت هذه السياسة سيُحدَّث التاريخ أعلاه.',
 },
 'en': {
  'title': 'Privacy Policy',
  'app': 'Kalar Guide',
  'updated': 'Last updated',
  'intro': 'This policy explains what information the "Kalar Guide" app collects, why, and how you can control it. The app can also be used without an account.',
  'sections': [
   ('Information we collect', [
     'Account: name, phone number and password (stored hashed; nobody can read it); or name and e-mail if you sign in with Google.',
     'Location (GPS): only with your permission — used on your phone for nearby places, the map, Qibla and prayer times, and not uploaded. A complaint\'s location is sent only when you submit a complaint.',
     'Complaints: the text, photos and voice recordings you add.',
     'Activity: favourite places, likes, reviews and places you suggest.',
     'Notifications: a notification token (FCM) to send you notifications.',
     'Statistics and errors: a random device ID, language and app version to count active users; analytics and crash reports through Firebase to improve the app.',
   ]),
   ('Why we use it', [
     'To show places, news, prices and services in Kalar.',
     'To deliver your complaint to the responsible office and update you on it.',
     'To protect your account and prevent abuse.',
     'We never sell your information or use it for advertising.',
   ]),
   ('Who we share it with', [
     'Supabase: data storage and sign-in.',
     'Google (Firebase, Google Sign-In, Google Maps, Gemini): notifications, analytics, crash reports, maps, and translating public content (place names and news — not personal information).',
     'Complaints: sent to the responsible government office.',
   ]),
   ('Retention and deletion', [
     'We keep your information while your account exists.',
     'You can permanently delete your account, favourites, likes and reviews at any time in Profile → "Delete account".',
     'Submitted complaints remain as official records but are no longer linked to your account.',
   ]),
   ('Your rights', [
     'You can turn off location and notification permissions in your phone settings.',
     'You can ask to see, correct or delete your information.',
   ]),
   ('Children', [
     'The app is for everyone, but it does not knowingly collect information from children under 13.',
   ]),
  ],
  'contact': 'Contact',
  'changes': 'If this policy changes, the date above will be updated.',
 },
}

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── Dart ──────────────────────────────────────────────────────────
def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"

lines = ['// lib/l10n/privacy_policy_text.dart',
         '// GENERATED by tool/privacy_policy.py — دەستکاری ئەو فایلە بکە، نەک ئەمە.',
         '// ignore_for_file: lines_longer_than_80_chars',
         '',
         'class PrivacySection {',
         '  const PrivacySection(this.title, this.points);',
         '  final String title;',
         '  final List<String> points;',
         '}',
         '',
         'class PrivacyPolicyText {',
         '  const PrivacyPolicyText({required this.title, required this.intro, required this.updatedLabel,',
         '      required this.sections, required this.contactLabel, required this.contactName, required this.changes});',
         '  final String title;',
         '  final String intro;',
         '  final String updatedLabel;',
         '  final List<PrivacySection> sections;',
         '  final String contactLabel;',
         '  final String contactName;',
         '  final String changes;',
         '',
         f"  static const String updated = {dart_str(UPDATED)};",
         f"  static const String contactPhone = {dart_str(CONTACT_PHONE)};",
         '',
         '  static PrivacyPolicyText of(String lang) => _all[lang] ?? _all[\'ku\']!;',
         '',
         '  static const Map<String, PrivacyPolicyText> _all = {']
for lang, p in POLICY.items():
    lines.append(f"    '{lang}': PrivacyPolicyText(")
    lines.append(f"      title: {dart_str(p['title'])},")
    lines.append(f"      intro: {dart_str(p['intro'])},")
    lines.append(f"      updatedLabel: {dart_str(p['updated'])},")
    lines.append(f"      contactLabel: {dart_str(p['contact'])},")
    lines.append(f"      contactName: {dart_str(CONTACT_NAME[lang])},")
    lines.append(f"      changes: {dart_str(p['changes'])},")
    lines.append("      sections: [")
    for t, pts in p['sections']:
        lines.append(f"        PrivacySection({dart_str(t)}, [")
        for x in pts:
            lines.append(f"          {dart_str(x)},")
        lines.append("        ]),")
    lines.append("      ],")
    lines.append("    ),")
lines += ['  };', '}', '']
open(os.path.join(root, 'lib/l10n/privacy_policy_text.dart'), 'w', encoding='utf-8').write('\n'.join(lines))

# ── HTML ──────────────────────────────────────────────────────────
e = html.escape
parts = []
for lang, p in POLICY.items():
    d = 'ltr' if lang == 'en' else 'rtl'
    secs = ''.join(
        f'<h2>{e(t)}</h2><ul>' + ''.join(f'<li>{e(x)}</li>' for x in pts) + '</ul>'
        for t, pts in p['sections'])
    parts.append(f'''<section id="{lang}" lang="{lang}" dir="{d}">
<h1>{e(p['title'])} — {e(p['app'])}</h1>
<p class="muted">{e(p['updated'])}: {UPDATED}</p>
<p>{e(p['intro'])}</p>
{secs}
<h2>{e(p['contact'])}</h2>
<p>{e(CONTACT_NAME[lang])} — <a href="tel:{CONTACT_PHONE.replace(' ', '')}" dir="ltr">{CONTACT_PHONE}</a></p>
<p class="muted">{e(p['changes'])}</p>
</section>''')
page = f'''<!DOCTYPE html>
<html lang="ku" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>سیاسەتی تایبەتمەندی — ڕێبەری کەلار | Privacy Policy — Kalar Guide</title>
<style>
 body{{margin:0;background:#f8fafc;color:#1a1a22;font:16px/1.75 system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif}}
 main{{max-width:760px;margin:0 auto;padding:24px 18px 60px}}
 nav{{display:flex;gap:8px;justify-content:center;margin:8px 0 18px}}
 nav a{{padding:6px 14px;border-radius:999px;background:#fff;border:1px solid #e2e8f0;color:#1e88e5;text-decoration:none;font-weight:600}}
 section{{background:#fff;border:1px solid #e8edf3;border-radius:18px;padding:22px 22px 10px;margin-bottom:18px}}
 h1{{font-size:22px;margin:0 0 4px;color:#1e88e5}} h2{{font-size:17px;margin:22px 0 6px}}
 ul{{padding-inline-start:22px;margin:0}} li{{margin:4px 0}} .muted{{color:#64748b;font-size:14px}}
 a{{color:#1e88e5}}
</style>
</head>
<body><main>
<nav><a href="#ku">کوردی</a><a href="#ar">العربية</a><a href="#en">English</a></nav>
{''.join(parts)}
</main></body></html>
'''
os.makedirs(os.path.join(root, 'docs'), exist_ok=True)
open(os.path.join(root, 'docs/privacy-policy.html'), 'w', encoding='utf-8').write(page)
print('ok')
