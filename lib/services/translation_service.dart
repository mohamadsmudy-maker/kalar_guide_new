import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🌍 وەرگێڕانی زیرەک — Dictionary + Gemini AI
///
/// ✅ چارەسەرکراو:
/// - وشە دووبارەکان لابراون
/// - `final` بەکارهێنراوە لە جیاتی `const`
/// - کۆمێنتە دووبارەکان پاککراونەتەوە
class TranslationService {
  static const String _cachePrefix = 'ai_trans_v5_';
  static const int _maxCacheEntries = 2000;
  static const Duration _timeout = Duration(seconds: 15);

  static bool _isInitialized = false;
  static String _apiKey = '';
  static final Map<String, String> _memoryCache = {};

  // ═══════════════════════════════════════════════════════════
  // 📚 Dictionary — سەرچاوەی یەکەم
  // ═══════════════════════════════════════════════════════════
  // ✅ final — چونکە هەندێک وشە هەن کە لە runtime زیاد دەکرێن
  static final Map<String, Map<String, String>> _wordDictionary = {
    // ═══════════════════════════════════════════════════════
    // 🏙️ ناوی شار و شوێنەکان
    // ═══════════════════════════════════════════════════════
    'کەلار': {'ar': 'كلار', 'en': 'Kalar'},
    'گەرمیان': {'ar': 'گرميان', 'en': 'Garmian'},
    'سلێمانی': {'ar': 'السليمانية', 'en': 'Sulaymaniyah'},
    'هەولێر': {'ar': 'أربيل', 'en': 'Erbil'},
    'کەرکووک': {'ar': 'كركوك', 'en': 'Kirkuk'},
    'دهۆک': {'ar': 'دهوك', 'en': 'Duhok'},
    'بەغدا': {'ar': 'بغداد', 'en': 'Baghdad'},
    'کوردستان': {'ar': 'كردستان', 'en': 'Kurdistan'},
    'عێراق': {'ar': 'العراق', 'en': 'Iraq'},
    'ئێران': {'ar': 'إيران', 'en': 'Iran'},
    'تورکیا': {'ar': 'تركيا', 'en': 'Turkey'},

    // ═══════════════════════════════════════════════════════
    // 🏛️ فەرمانگەکان
    // ═══════════════════════════════════════════════════════
    'فەرمانگە': {'ar': 'دائرة', 'en': 'Department'},
    'فەرمانگەکان': {'ar': 'الدوائر', 'en': 'Departments'},
    'بەڕێوەبەرایەتی': {'ar': 'مديرية', 'en': 'Directorate'},
    'بەڕێوەبەرایەتی هاتوچۆ': {
      'ar': 'مديرية المرور',
      'en': 'Traffic Directorate',
    },
    'بەڕێوەبەرایەتی شارەوانی': {
      'ar': 'مديرية البلدية',
      'en': 'Municipality Directorate',
    },
    'بەڕێوەبەرایەتی پاسپۆرت': {
      'ar': 'مديرية الجوازات',
      'en': 'Passport Directorate',
    },
    'بەڕێوەبەرایەتی تەندروستی': {
      'ar': 'مديرية الصحة',
      'en': 'Health Directorate',
    },
    'بەڕێوەبەرایەتی پەروەردە': {
      'ar': 'مديرية التربية',
      'en': 'Education Directorate',
    },
    'بەڕێوەبەرایەتی کارەبا': {
      'ar': 'مديرية الكهرباء',
      'en': 'Electricity Directorate',
    },
    'بەڕێوەبەرایەتی ئاو': {
      'ar': 'مديرية الماء',
      'en': 'Water Directorate',
    },
    'قایمقامیەت': {'ar': 'قائممقامية', 'en': 'District Governorate'},
    'قایمقامیەتی قەزای کەلار': {
      'ar': 'قائممقامية قضاء كلار',
      'en': 'Kalar District Governorate',
    },
    'شارەوانی': {'ar': 'بلدية', 'en': 'Municipality'},
    'سەرۆکایەتی شارەوانی کەلار': {
      'ar': 'رئاسة بلدية كلار',
      'en': 'Kalar Municipality Presidency',
    },
    'هاتوچۆ': {'ar': 'المرور', 'en': 'Traffic'},
    'پاسپۆرت': {'ar': 'الجوازات', 'en': 'Passport'},
    'پارێزگا': {'ar': 'محافظة', 'en': 'Governorate'},
    'وەزارەت': {'ar': 'وزارة', 'en': 'Ministry'},
    'کارەبا': {'ar': 'الكهرباء', 'en': 'Electricity'},
    'ئاو': {'ar': 'الماء', 'en': 'Water'},
    'گاز': {'ar': 'الغاز', 'en': 'Gas'},
    'دادگا': {'ar': 'المحكمة', 'en': 'Court'},
    'پۆلیس': {'ar': 'الشرطة', 'en': 'Police'},
    'بانک': {'ar': 'مصرف', 'en': 'Bank'},
    'سەرۆکایەتی': {'ar': 'رئاسة', 'en': 'Presidency'},

    // ═══════════════════════════════════════════════════════
    // 📋 مامەڵەکان
    // ═══════════════════════════════════════════════════════
    'مامەڵە': {'ar': 'معاملة', 'en': 'Transaction'},
    'مامەڵەکان': {'ar': 'المعاملات', 'en': 'Transactions'},
    'دەرهێنان': {'ar': 'استخراج', 'en': 'Issuance'},
    'تازەکردنەوە': {'ar': 'تجديد', 'en': 'Renewal'},
    'گواستنەوەی خاوەندارێتی': {
      'ar': 'نقل الملكية',
      'en': 'Ownership Transfer',
    },
    'مۆڵەتی شۆفێری': {'ar': 'رخصة القيادة', 'en': 'Driving License'},
    'دەرهێنانی مۆڵەتی شۆفێری': {
      'ar': 'استخراج رخصة القيادة',
      'en': 'Driving License Issuance',
    },
    'تازەکردنەوەی مۆڵەتی شۆفێری': {
      'ar': 'تجديد رخصة القيادة',
      'en': 'Driving License Renewal',
    },
    'مۆڵەتی بیناکردن': {'ar': 'رخصة البناء', 'en': 'Building Permit'},
    'مۆڵەتی بازرگانی': {
      'ar': 'الرخصة التجارية',
      'en': 'Commercial License',
    },
    'مۆڵەتی پیشەسازی': {
      'ar': 'الرخصة الصناعية',
      'en': 'Industrial License',
    },
    'دەرهێنانی پاسپۆرت': {
      'ar': 'استخراج جواز سفر',
      'en': 'Passport Issuance',
    },
    'تازەکردنەوەی پاسپۆرت': {
      'ar': 'تجديد جواز السفر',
      'en': 'Passport Renewal',
    },
    'کارتی نیشتمانی': {'ar': 'البطاقة الوطنية', 'en': 'National ID'},
    'کارتی زانیاری': {'ar': 'بطاقة المعلومات', 'en': 'Information Card'},
    'ناسنامەی نیشتمانی': {'ar': 'الهوية الوطنية', 'en': 'National ID'},
    'چەسپاندنی سنوور': {
      'ar': 'تصديق الحدود',
      'en': 'Boundary Certification',
    },
    'وێنەی تۆمار': {'ar': 'صورة السجل', 'en': 'Registry Photo'},
    'بریکارنامە': {'ar': 'وكالة', 'en': 'Power of Attorney'},
    'پشکنینی پزیشکی': {'ar': 'الفحص الطبي', 'en': 'Medical Check'},
    'کۆدی سەردانیکردن': {
      'ar': 'رمز الحجز',
      'en': 'Appointment Code',
    },
    'مۆڵەتی نووسینگە': {'ar': 'رخصة المكتب', 'en': 'Office Permit'},
    'مۆڵەتی کۆمپانیا': {'ar': 'رخصة الشركة', 'en': 'Company License'},
    'تۆمارکردنی کۆمپانیا': {
      'ar': 'تسجيل الشركة',
      'en': 'Company Registration',
    },
    'تۆمارکردنی بازرگانی': {
      'ar': 'تسجيل تجاري',
      'en': 'Commercial Registration',
    },
    'ڕاپۆرتی پۆلیس': {'ar': 'تقرير الشرطة', 'en': 'Police Report'},
    'شەهادەتی لەدایکبوون': {
      'ar': 'شهادة الميلاد',
      'en': 'Birth Certificate',
    },
    'شەهادەتی مردن': {'ar': 'شهادة الوفاة', 'en': 'Death Certificate'},
    'شەهادەتی زواج': {'ar': 'عقد الزواج', 'en': 'Marriage Certificate'},
    'جیاکردنەوەی زواج': {'ar': 'الطلاق', 'en': 'Divorce'},
    'وەرگرتنی موڵک': {'ar': 'استلام العقار', 'en': 'Property Receipt'},
    'گواستنەوەی موڵک': {
      'ar': 'نقل الملكية العقارية',
      'en': 'Property Transfer',
    },

    // ═══════════════════════════════════════════════════════
    // 📂 بەشەکان
    // ═══════════════════════════════════════════════════════
    'بەش': {'ar': 'قسم', 'en': 'Category'},
    'بەشەکان': {'ar': 'الأقسام', 'en': 'Categories'},
    'بەشە سەرەکییەکان': {
      'ar': 'الأقسام الرئيسية',
      'en': 'Main Categories',
    },
    'ژێربەش': {'ar': 'قسم فرعي', 'en': 'Sub-category'},
    'ژێربەشەکان': {'ar': 'الأقسام الفرعية', 'en': 'Sub-categories'},
    'تەندروستی': {'ar': 'الصحة', 'en': 'Health'},
    'پەروەردە': {'ar': 'التربية', 'en': 'Education'},
    'خوێندنی باڵا': {'ar': 'التعليم العالي', 'en': 'Higher Education'},
    'خواردن': {'ar': 'الطعام', 'en': 'Food'},
    'بازاڕگەری': {'ar': 'التسوق', 'en': 'Shopping'},
    'سوتەمەنی': {'ar': 'الوقود', 'en': 'Fuel'},
    'وەرزش': {'ar': 'الرياضة', 'en': 'Sports'},
    'کلتوور': {'ar': 'الثقافة', 'en': 'Culture'},
    'گەشتوگوزار': {'ar': 'السياحة', 'en': 'Tourism'},
    'کات بەسەربردن': {'ar': 'الترفيه', 'en': 'Entertainment'},
    'پیشەسازی': {'ar': 'الصناعة', 'en': 'Industry'},
    'کشتوکاڵ': {'ar': 'الزراعة', 'en': 'Agriculture'},
    'ئاینی': {'ar': 'ديني', 'en': 'Religious'},
    'خزمەتگوزاری': {'ar': 'خدمات', 'en': 'Services'},
    'فێرکاری': {'ar': 'التعليم', 'en': 'Teaching'},

    // ═══════════════════════════════════════════════════════
    // 🏪 شوێنەکان
    // ═══════════════════════════════════════════════════════
    'شوێن': {'ar': 'مكان', 'en': 'Place'},
    'شوێنەکان': {'ar': 'الأماكن', 'en': 'Places'},
    'شوێنێک': {'ar': 'مكان', 'en': 'Place'},
    'شوێنی وەرزشی': {'ar': 'مكان رياضي', 'en': 'Sports Venue'},
    'شوێنی گەشتیاری': {'ar': 'مكان سياحي', 'en': 'Tourist Place'},
    'شوێنی ئاینی': {'ar': 'مكان ديني', 'en': 'Religious Place'},
    'شوێنی خواردن': {'ar': 'مكان طعام', 'en': 'Food Place'},
    'شوێنی کڕین': {'ar': 'مكان تسوق', 'en': 'Shopping Place'},
    'شوێنی خزمەتگوزاری': {
      'ar': 'مكان خدماتي',
      'en': 'Service Place',
    },
    'شوێنی حکومی': {'ar': 'مكان حكومي', 'en': 'Government Place'},
    'شوێنی ناحکومی': {'ar': 'مكان خاص', 'en': 'Private Place'},
    'حکومی': {'ar': 'حكومي', 'en': 'Government'},
    'ناحکومی': {'ar': 'غير حكومي', 'en': 'Non-Government'},
    'فرۆشگا': {'ar': 'متجر', 'en': 'Store'},
    'دوکان': {'ar': 'دكان', 'en': 'Shop'},
    'سوپەرمارکێت': {'ar': 'سوبر ماركت', 'en': 'Supermarket'},
    'ڕێستۆرانت': {'ar': 'مطعم', 'en': 'Restaurant'},
    'چێشتخانە': {'ar': 'مطعم', 'en': 'Restaurant'},
    'کافێ': {'ar': 'مقهى', 'en': 'Cafe'},
    'هۆتێل': {'ar': 'فندق', 'en': 'Hotel'},
    'شیرینی': {'ar': 'حلويات', 'en': 'Sweets'},
    'قەسابخانە': {'ar': 'جزارة', 'en': 'Butcher'},
    'نانەوایی': {'ar': 'مخبز', 'en': 'Bakery'},
    'دەرمانخانە': {'ar': 'صيدلية', 'en': 'Pharmacy'},
    'پزیشکخانە': {'ar': 'عيادة', 'en': 'Clinic'},
    'نەخۆشخانە': {'ar': 'مستشفى', 'en': 'Hospital'},
    'قوتابخانە': {'ar': 'مدرسة', 'en': 'School'},
    'زانکۆ': {'ar': 'جامعة', 'en': 'University'},
    'پەیمانگا': {'ar': 'معهد', 'en': 'Institute'},
    'کتێبخانە': {'ar': 'مكتبة', 'en': 'Library'},
    'مۆزەخانە': {'ar': 'متحف', 'en': 'Museum'},
    'مزگەوت': {'ar': 'مسجد', 'en': 'Mosque'},
    'پارک': {'ar': 'حديقة', 'en': 'Park'},
    'یاریگا': {'ar': 'ملعب', 'en': 'Stadium'},
    'بەنزینخانە': {'ar': 'محطة وقود', 'en': 'Gas Station'},
    'گەراج': {'ar': 'كراج', 'en': 'Garage'},
    'نوسینگەی دراو': {'ar': 'مكتب الصرافة', 'en': 'Currency Exchange'},

    // ═══════════════════════════════════════════════════════
    // 🏘️ گەڕەکەکان
    // ═══════════════════════════════════════════════════════
    'گەڕەک': {'ar': 'حي', 'en': 'Neighborhood'},
    'گەڕەکی': {'ar': 'حي', 'en': 'District'},
    'گەڕەکەکان': {'ar': 'الأحياء', 'en': 'Neighborhoods'},
    'ئەندازیاران': {'ar': 'المهندسين', 'en': 'Engineers'},
    'شەهیدان': {'ar': 'الشهداء', 'en': 'Martyrs'},
    'ئازادی': {'ar': 'الحرية', 'en': 'Azadi'},
    'نەورۆز': {'ar': 'نوروز', 'en': 'Newroz'},
    'ڕزگاری': {'ar': 'التحرير', 'en': 'Rizgari'},
    'شەقام': {'ar': 'شارع', 'en': 'Street'},
    'گەرەکی ئاسایش': {
      'ar': 'حي الأمن',
      'en': 'Security Neighborhood',
    },
    'گەرەکی زانکۆ': {
      'ar': 'حي الجامعة',
      'en': 'University Neighborhood',
    },
    'گەرەکی بازاڕ': {
      'ar': 'حي السوق',
      'en': 'Market Neighborhood',
    },

    // ═══════════════════════════════════════════════════════
    // 📰 هەواڵ و ڕووداوەکان
    // ═══════════════════════════════════════════════════════
    'هەواڵ': {'ar': 'خبر', 'en': 'News'},
    'هەواڵەکان': {'ar': 'الأخبار', 'en': 'News'},
    'ئاگاداری': {'ar': 'إشعار', 'en': 'Announcement'},
    'ڕووداو': {'ar': 'حدث', 'en': 'Event'},
    'ڕووداوەکان': {'ar': 'الأحداث', 'en': 'Events'},
    'نیشتمانی': {'ar': 'وطني', 'en': 'National'},
    'وەرزشی': {'ar': 'رياضي', 'en': 'Sports'},
    'کلتوری': {'ar': 'ثقافي', 'en': 'Cultural'},
    'تایبەت': {'ar': 'خاص', 'en': 'Featured'},
    'گرنگ': {'ar': 'مهم', 'en': 'Important'},

    // ═══════════════════════════════════════════════════════
    // 🚨 فریاکەوتن
    // ═══════════════════════════════════════════════════════
    'فریاکەوتن': {'ar': 'الطوارئ', 'en': 'Emergency'},
    'ئاگرکوژێنەوە': {'ar': 'الإطفاء', 'en': 'Fire Department'},
    'ئەمبولانس': {'ar': 'الإسعاف', 'en': 'Ambulance'},
    'ژەهرکوژراو': {'ar': 'مكافحة السموم', 'en': 'Poison Control'},
    'دیفاعی شارستانی': {
      'ar': 'الدفاع المدني',
      'en': 'Civil Defense',
    },

    // ═══════════════════════════════════════════════════════
    // 💱 دراو + سووتەمەنی
    // ═══════════════════════════════════════════════════════
    'دۆلاری ئەمەریکی': {
      'ar': 'الدولار الأمريكي',
      'en': 'US Dollar',
    },
    'دیناری عێراقی': {
      'ar': 'الدينار العراقي',
      'en': 'Iraqi Dinar',
    },
    'یۆرۆ': {'ar': 'اليورو', 'en': 'Euro'},
    'پاوەندی ئینگلیزی': {
      'ar': 'الجنيه الإسترليني',
      'en': 'British Pound',
    },
    'لیرەی تورکی': {'ar': 'الليرة التركية', 'en': 'Turkish Lira'},
    'زێڕ': {'ar': 'الذهب', 'en': 'Gold'},
    'زیو': {'ar': 'الفضة', 'en': 'Silver'},
    'ئاسایی': {'ar': 'عادي', 'en': 'Normal'},
    'سوپەر': {'ar': 'سوبر', 'en': 'Super'},
    'محەسەن': {'ar': 'محسن', 'en': 'Muhassen'},
    'زەیت': {'ar': 'زيت', 'en': 'Oil'},
    'بەنزین': {'ar': 'بنزين', 'en': 'Petrol'},

    // ═══════════════════════════════════════════════════════
    // 🎯 وشە گشتییەکان
    // ═══════════════════════════════════════════════════════
    'زیادکردن': {'ar': 'إضافة', 'en': 'Add'},
    'دەستکاری': {'ar': 'تعديل', 'en': 'Edit'},
    'سڕینەوە': {'ar': 'حذف', 'en': 'Delete'},
    'گەڕان': {'ar': 'بحث', 'en': 'Search'},
    'پاشەکەوت': {'ar': 'حفظ', 'en': 'Save'},
    'پاشگەزبوونەوە': {'ar': 'إلغاء', 'en': 'Cancel'},
    'بینین': {'ar': 'عرض', 'en': 'View'},
    'پەیوەندی': {'ar': 'اتصال', 'en': 'Call'},
    'نوێکردنەوە': {'ar': 'تحديث', 'en': 'Update'},
    'هەڵبژاردن': {'ar': 'اختيار', 'en': 'Select'},
    'تەواو': {'ar': 'مكتمل', 'en': 'Completed'},
    'چاوەڕوان': {'ar': 'قيد الانتظار', 'en': 'Pending'},
    'ڕەتکراو': {'ar': 'مرفوض', 'en': 'Rejected'},
    'پەسەندکراو': {'ar': 'مقبول', 'en': 'Approved'},
    'هەڵە': {'ar': 'خطأ', 'en': 'Error'},
    'سەرکەوتوو': {'ar': 'ناجح', 'en': 'Success'},
    'هۆشداری': {'ar': 'تحذير', 'en': 'Warning'},
    'دڵنیایی': {'ar': 'تأكيد', 'en': 'Confirm'},
    'بەڵێ': {'ar': 'نعم', 'en': 'Yes'},
    'نەخێر': {'ar': 'لا', 'en': 'No'},
    'باشە': {'ar': 'حسناً', 'en': 'OK'},
    'داخستن': {'ar': 'إغلاق', 'en': 'Close'},
    'کردنەوە': {'ar': 'فتح', 'en': 'Open'},
    'پارەدان': {'ar': 'الدفع', 'en': 'Payment'},
    'وەرگرتن': {'ar': 'استلام', 'en': 'Receive'},
    'ناردن': {'ar': 'إرسال', 'en': 'Send'},
    'تۆمارکردن': {'ar': 'تسجيل', 'en': 'Register'},
    'هەموو': {'ar': 'الكل', 'en': 'All'},
    'هیچ': {'ar': 'لا شيء', 'en': 'None'},
    'زیاتر': {'ar': 'المزيد', 'en': 'More'},
    'کەمتر': {'ar': 'أقل', 'en': 'Less'},
    'دووبارە': {'ar': 'مرة أخرى', 'en': 'Again'},

    // ═══════════════════════════════════════════════════════
    // 🕐 کاتەکان
    // ═══════════════════════════════════════════════════════
    'ئێستا': {'ar': 'الآن', 'en': 'Now'},
    'چرکە': {'ar': 'ثانية', 'en': 'Second'},
    'خولەک': {'ar': 'دقيقة', 'en': 'Minute'},
    'دەقیقە': {'ar': 'دقيقة', 'en': 'Minute'},
    'کاتژمێر': {'ar': 'ساعة', 'en': 'Hour'},
    'سەعات': {'ar': 'ساعة', 'en': 'Hour'},
    'ڕۆژ': {'ar': 'يوم', 'en': 'Day'},
    'هەفتە': {'ar': 'أسبوع', 'en': 'Week'},
    'مانگ': {'ar': 'شهر', 'en': 'Month'},
    'ساڵ': {'ar': 'سنة', 'en': 'Year'},
    'لەمەوبەر': {'ar': 'منذ', 'en': 'ago'},
    'لەمەودوا': {'ar': 'في', 'en': 'in'},
    'دوێنێ': {'ar': 'أمس', 'en': 'Yesterday'},
    'ئەمڕۆ': {'ar': 'اليوم', 'en': 'Today'},
    'سبەی': {'ar': 'غداً', 'en': 'Tomorrow'},
    'بەیانی': {'ar': 'صباحاً', 'en': 'Morning'},
    'نیوەڕۆ': {'ar': 'ظهراً', 'en': 'Noon'},
    'ئێوارە': {'ar': 'مساءً', 'en': 'Evening'},
    'شەو': {'ar': 'ليلاً', 'en': 'Night'},

    // ═══════════════════════════════════════════════════════
    // 📋 پێداویستی + تێچوو
    // ═══════════════════════════════════════════════════════
    'پێداویستی': {'ar': 'متطلب', 'en': 'Requirement'},
    'پێداویستییەکان': {'ar': 'المتطلبات', 'en': 'Requirements'},
    'تێچوو': {'ar': 'رسم', 'en': 'Fee'},
    'تێچووەکان': {'ar': 'الرسوم', 'en': 'Fees'},
    'نرخ': {'ar': 'السعر', 'en': 'Price'},
    'نرخەکان': {'ar': 'الأسعار', 'en': 'Prices'},
    'ماوە': {'ar': 'المدة', 'en': 'Duration'},
    'ناونیشان': {'ar': 'العنوان', 'en': 'Address'},
    'ژمارە': {'ar': 'رقم', 'en': 'Number'},
    'ژمارەی مۆبایل': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'بەروار': {'ar': 'التاريخ', 'en': 'Date'},
    'دۆخ': {'ar': 'الحالة', 'en': 'Status'},
    'تێبینی': {'ar': 'ملاحظات', 'en': 'Notes'},

    // ═══════════════════════════════════════════════════════
    // 🔢 ژمارەکان
    // ═══════════════════════════════════════════════════════
    'یەک': {'ar': 'واحد', 'en': 'One'},
    'دوو': {'ar': 'اثنان', 'en': 'Two'},
    'سێ': {'ar': 'ثلاثة', 'en': 'Three'},
    'چوار': {'ar': 'أربعة', 'en': 'Four'},
    'پێنج': {'ar': 'خمسة', 'en': 'Five'},
    'شەش': {'ar': 'ستة', 'en': 'Six'},
    'حەوت': {'ar': 'سبعة', 'en': 'Seven'},
    'هەشت': {'ar': 'ثمانية', 'en': 'Eight'},
    'نۆ': {'ar': 'تسعة', 'en': 'Nine'},
    'دە': {'ar': 'عشرة', 'en': 'Ten'},
  };

  // ═══════════════════════════════════════════════════════════
  // 🚀 دەستپێکردن
  // ═══════════════════════════════════════════════════════════
  static void _init() {
    if (_isInitialized) return;

    try {
      _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (_) {
      _apiKey = '';
    }

    if (_apiKey.isEmpty) {
      _apiKey = const String.fromEnvironment(
        'GEMINI_API_KEY',
        defaultValue: '',
      );
    }

    _isInitialized = true;

    debugPrint(
      _apiKey.isEmpty
          ? '⚠️ TranslationService: Dictionary Mode (بێ AI)'
          : '✅ TranslationService: Hybrid Mode',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 API ی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'ku',
  }) async {
    _init();

    final trimmed = text.trim();

    if (trimmed.isEmpty) return text;
    if (targetLanguage == sourceLanguage) return text;
    if (targetLanguage == 'ku') return text;

    final cacheKey = '$sourceLanguage|$targetLanguage|$trimmed';

    // ✅ ١. Memory Cache — خێراترین
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // ✅ ٢. Disk Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cachePrefix$cacheKey');
      if (cached != null && cached.isNotEmpty) {
        _memoryCache[cacheKey] = cached;
        return cached;
      }
    } catch (_) {}

    // ✅ ٣. Dictionary — ئەگەر دەقی تەواو هەبوو
    final exactMatch = _wordDictionary[trimmed]?[targetLanguage];
    if (exactMatch != null) {
      _memoryCache[cacheKey] = exactMatch;
      await _saveToDisk(cacheKey, exactMatch);
      debugPrint('📚 [Dict] $trimmed → $exactMatch');
      return exactMatch;
    }

    // ✅ ٤. Hybrid — وەرگێڕانی وشە بە وشە
    final hybrid = _hybridTranslate(trimmed, targetLanguage);
    if (hybrid != null && hybrid != trimmed) {
      _memoryCache[cacheKey] = hybrid;
      await _saveToDisk(cacheKey, hybrid);
      debugPrint('🔀 [Hybrid] $trimmed → $hybrid');
      return hybrid;
    }

    // ✅ ٥. AI — تەنها ئەگەر پێویست بوو
    if (_apiKey.isEmpty) {
      return text; // Dictionary Mode
    }

    final aiResult = await _aiTranslate(trimmed, targetLanguage);
    _memoryCache[cacheKey] = aiResult;
    await _saveToDisk(cacheKey, aiResult);
    return aiResult;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔀 وەرگێڕانی وشە بە وشە
  // ═══════════════════════════════════════════════════════════
  static String? _hybridTranslate(String text, String targetLang) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 2) return null;

    int translatedCount = 0;
    final result = <String>[];

    for (final word in words) {
      if (word.isEmpty) continue;

      final cleanWord = word
          .replaceAll(RegExp(r'[،.,:;!?؟\-()«»]'), '')
          .trim();

      final translation = _wordDictionary[cleanWord]?[targetLang];
      if (translation != null) {
        result.add(translation);
        translatedCount++;
      } else {
        result.add(word);
      }
    }

    // ⭐ ٧٠٪ وشەکان پێویستە وەرگێڕدرابن
    final ratio = translatedCount / words.length;
    if (ratio < 0.7) return null;

    return result.join(' ');
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 AI Translate
  // ═══════════════════════════════════════════════════════════
  static Future<String> _aiTranslate(
      String text,
      String targetLang,
      ) async {
    _init();
    if (_apiKey.isEmpty) return text;

    try {
      final langName = _langName(targetLang);

      final systemInstruction = '''
You are a professional translator for "Kalar Guide" — a city guide app for Kalar, Kurdistan Region of Iraq.

TASK: Translate the given Kurdish (Sorani) text into $langName.

RULES:
1. If it's a PERSONAL NAME or BRAND → transliterate to Latin/Arabic script.
2. If it's a NEIGHBORHOOD name → transliterate.
3. If it's a CATEGORY → use the standard term.
4. Keep numbers, English words, and emojis as-is.
5. If unsure, keep it in the original Kurdish.
6. Return ONLY valid JSON.

OUTPUT FORMAT:
{"translation": "your translation here"}
''';

      final userContent = jsonEncode({
        'text': text,
        'target': targetLang,
      });

      final model = dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';
      final apiVersion = dotenv.env['GEMINI_API_VERSION'] ?? 'v1beta';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$_apiKey',
      );

      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': userContent}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 500,
          },
        }),
      )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw =
            data['candidates']?[0]?['content']?['parts']?[0]['text']
                ?.toString()
                .trim() ??
                '';

        if (raw.isEmpty) return text;

        try {
          final parsed = jsonDecode(raw);
          final translated = parsed['translation']?.toString() ?? text;
          return _cleanAiOutput(translated, text);
        } catch (_) {
          return _cleanAiOutput(raw, text);
        }
      }

      return text;
    } catch (e) {
      debugPrint('❌ AI error: $e');
      return text;
    }
  }

  static String _cleanAiOutput(String raw, String fallback) {
    var cleaned = raw
        .replaceAll(RegExp(r"""^["'\s]+|["'\s]+$"""), '')
        .replaceAll(RegExp(r'^(Translation|وەرگێڕان|الترجمة)\s*:\s*'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();

    if (cleaned.isEmpty || cleaned.length > 500) {
      return fallback;
    }
    return cleaned;
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 Cache
  // ═══════════════════════════════════════════════════════════
  static Future<void> _saveToDisk(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', value);

      final keys =
      prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
      if (keys.length > _maxCacheEntries) {
        final toRemove = keys.take(keys.length - _maxCacheEntries);
        for (final k in toRemove) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }

  static Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  static Map<String, int> getCacheStats() {
    return {
      'memory': _memoryCache.length,
      'dictionary': _wordDictionary.length,
    };
  }

  static String _langName(String code) {
    switch (code) {
      case 'ar':
        return 'Arabic';
      case 'en':
        return 'English';
      case 'ku':
        return 'Kurdish Sorani';
      default:
        return 'English';
    }
  }
}