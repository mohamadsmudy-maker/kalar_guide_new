// lib/config/translations.dart
import 'package:flutter/foundation.dart';

/// 🌍 وەرگێڕانەکانی ئەپ — ULTRA PRO MAX V2
///
/// ✅ هەموو کلیلەکانی شاشەی سەرەکی و دراوەر زیادکران (پێشتر لە ئینگلیزی/عەرەبی بە کوردی دەردەکەوتن)
/// ✅ [missingKeys] بۆ دۆزینەوەی کلیلی ون لە debug
/// ✅ هەڵەی ڕێنووسی عەرەبی چاککرا
class AppTranslations {
  AppTranslations._();

  static const List<String> supportedLanguages = ['ku', 'ar', 'en'];
  static const String fallbackLanguage = 'ku';

  static const Map<String, Map<String, String>> _translations = {
    'ar': _ar,
    'en': _en,
    'ku': _ku,
  };

  static String t(String key, String lang) {
    final map = _translations[lang];
    final value = map?[key];
    if (value != null) return value;

    return _translations[fallbackLanguage]?[key] ?? key;
  }

  static String tWithParams(
      String key,
      String lang,
      Map<String, String> params,
      ) {
    var text = t(key, lang);
    params.forEach((k, v) {
      text = text.replaceAll('{$k}', v);
    });
    return text;
  }

  static bool hasKey(String key, String lang) {
    return _translations[lang]?.containsKey(key) ?? false;
  }

  static List<String> getKeys(String lang) {
    return _translations[lang]?.keys.toList() ?? [];
  }

  static bool isSupported(String lang) => _translations.containsKey(lang);

  /// کلیلەکانی زمانی سەرەکی (کوردی) کە لە [lang] دا نین.
  static List<String> missingKeys(String lang) {
    final target = _translations[lang] ?? const <String, String>{};
    return _ku.keys.where((k) => !target.containsKey(k)).toList();
  }

  /// لە debug دا هۆشدارییەک چاپ دەکات ئەگەر زمانێک کلیلی ونی هەبێت.
  /// لە main() دا یەک جار بانگی بکە.
  static void debugCheck() {
    if (!kDebugMode) return;
    for (final lang in supportedLanguages) {
      final missing = missingKeys(lang);
      if (missing.isNotEmpty) {
        debugPrint('🌍 [$lang] missing ${missing.length} keys: ${missing.join(', ')}');
      }
    }
  }

  static String languageNativeName(String lang) {
    switch (lang) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'ku':
      default:
        return 'کوردی';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🇮🇶 کوردی
  // ═══════════════════════════════════════════════════════════
  static const Map<String, String> _ku = {
    'app_name': 'ڕێبەری کەلار',
    'app_subtitle': 'ڕێبەری فەرمی شاری کەلار',
    'welcome_guest': 'میوانی خۆشەویست',
    'loading': 'خەریکی بارکردن...',
    'error': 'هەڵە',
    'retry': 'دووبارە هەوڵبدە',
    'ok': 'باشە',
    'cancel': 'پاشگەزبوونەوە',
    'save': 'پاشەکەوت',
    'delete': 'سڕینەوە',
    'edit': 'دەستکاری',
    'add': 'زیادکردن',
    'close': 'داخستن',
    'search': 'گەڕان',
    'no_results': 'هیچ ئەنجامێک نەدۆزرایەوە',
    'no_data': 'هیچ داتایەک نییە',
    'confirm': 'دڵنیابوونەوە',
    'yes': 'بەڵێ',
    'no': 'نەخێر',
    'next': 'دواتر',
    'previous': 'پێشوو',
    'done': 'تەواو',
    'skip': 'بازدان',
    'all': 'هەموو',
    'more': 'زیاتر',
    'less': 'کەمتر',
    'see_all': 'بینینی هەموو',
    'updated': 'نوێکرایەوە',
    'version': 'وەشان',
    'language': 'زمان',
    'required': 'پێویستە',
    'optional': 'ئیختیاری',
    'success': 'سەرکەوتوو',
    'failed': 'شکستهێنا',
    'unknown_error': 'هەڵەی نەزانراو',

    'nav_home': 'سەرەکی',
    'nav_places': 'شوێنەکان',
    'nav_categories': 'بەشەکان',
    'nav_favorites': 'دڵخواز',
    'nav_daily': 'ڕۆژانە',
    'nav_search': 'گەڕان',
    'nav_cart': 'سەبەتە',
    'nav_orders': 'داواکارییەکانم',
    'nav_profile': 'پرۆفایلم',
    'nav_settings': 'ڕێکخستن',
    'nav_videos': 'ڤیدیۆکان',
    'nav_logout': 'چوونەدەرەوە',
    'nav_login': 'چوونەژوورەوە',
    'nav_admin': 'پانێڵی بەڕێوەبردن',
    'nav_emergency': 'فریاکەوتن',
    'nav_events': 'ڕووداوەکان',

    'stores': 'شوێنەکان',
    'stores_map': 'نەخشەی شوێنەکان',
    'stores_search_hint': 'گەڕان بەدوای شوێن...',
    'stores_count': '{count} شوێن دۆزرایەوە',
    'stores_government': 'حکومی',
    'stores_non_government': 'ناحکومی',
    'stores_all': 'هەموو',
    'stores_nearest': 'نزیکترین',
    'store_address': 'ناونیشان',
    'store_phone': 'مۆبایل',
    'store_description': 'وەسف',
    'store_visit': 'سەردان',
    'store_call': 'پەیوەندی',
    'store_whatsapp': 'واتسئاپ',
    'store_map': 'شوێن لەسەر نەخشە',

    'cat_health': 'تەندروستی',
    'cat_education': 'پەروەردە',
    'cat_higher_ed': 'خوێندنی باڵا',
    'cat_government': 'بەڕێوەبەرایەتی',
    'cat_food': 'خواردن',
    'cat_shopping': 'بازاڕگەری',

    'home_news': 'هەواڵ و ئاگادارییە گرنگەکان',
    'home_send_complaint': 'ناردنی سکاڵای هاوڵاتی',
    'home_complaint_subtitle': 'کێشە یان گرفتێک لە شاردا بنێرە',
    'home_main_categories': 'بەشە سەرەکییەکان',
    'home_more_news': 'هەواڵی زیاتر',

    'complaint_title': 'ناردنی سکاڵا',
    'complaint_send': 'ناردن',
    'complaint_approved': 'سکاڵاکەت پەسەندکرا',
    'complaint_pending': 'لە پێداچوونەوەدا',
    'complaint_resolved': 'چارەسەرکرا',

    'cart': 'سەبەتە',
    'cart_empty': 'سەبەتە بەتاڵە',
    'cart_total': 'کۆی گشتی',
    'cart_checkout': 'کڕین',
    'cart_add': 'زیادکردن بۆ سەبەتە',

    'orders': 'داواکارییەکانم',
    'orders_empty': 'هیچ داواکارییەک نییە',

    'profile': 'پرۆفایلم',
    'profile_name': 'ناو',
    'profile_phone': 'مۆبایل',
    'profile_logout': 'چوونەدەرەوە',

    'settings': 'ڕێکخستنەکان',
    'settings_font': 'جۆری فۆنت',
    'settings_font_size': 'قەبارەی فۆنت',
    'settings_language': 'زمان',
    'settings_theme': 'ڕەنگی ئەپ',
    'settings_notifications': 'ئاگادارکردنەوە',
    'settings_preview': 'پێشبینین',
    'settings_reset': 'گەڕاندنەوە بۆ دۆخی سەرەتا',
    'settings_theme_light': 'ڕووناک',
    'settings_theme_dark': 'تاریک',
    'settings_theme_system': 'سیستەم',
    'settings_font_small': 'بچووک',
    'settings_font_normal': 'ئاسایی',
    'settings_font_large': 'گەورە',
    'settings_font_xlarge': 'زۆر گەورە',
    'settings_reset_confirm': 'ئایا دڵنیایت لە گەڕاندنەوەی هەموو ڕێکخستنەکان؟',

    'prayer_times': 'کاتەکانی نوێژ',
    'qibla': 'قیبلە',
    'qibla_finder': 'قیبلە دۆزەرەوە',
    'weather': 'کەشوهەوا',
    'currency': 'دراوەکان',
    'fuel': 'نرخی سووتەمەنی',

    'auth_login': 'چوونەژوورەوە',
    'auth_signup': 'دروستکردنی ئەکاونت',
    'auth_phone': 'ژمارەی مۆبایل',
    'auth_password': 'پاسۆرد',
    'auth_name': 'ناوی تەواو',
    'auth_logout_success': 'بە سەرکەوتوویی چوویتە دەرەوە',
    'auth_welcome_back': 'بەخێربێیتەوە',
    'auth_login_failed': 'چوونەژوورەوە سەرنەکەوت',
    'auth_invalid_phone': 'ژمارەی مۆبایل نادروستە',
    'auth_weak_password': 'پاسۆرد لاوازە',

    // ─── شاشەی سەرەکی ───
    'menu': 'مێنیو',
    'back_to_top': 'سەرەوە',
    'other_services': 'خزمەتگوزارییەکانی تر',
    'more_news': 'هەواڵەکانی تر',
    'see_all_news': 'بینینی هەموو هەواڵەکان',
    'no_news': 'هیچ هەواڵێک نییە',
    'no_more_news': 'هیچ هەواڵێکی تر نییە',
    'pull_to_refresh': 'بۆ نوێکردنەوە ڕایبکێشە خوارەوە',
    'neighborhoods': 'گەڕەکان',
    'map': 'نەخشە',
    'gallery': 'گەلەری',
    'send_complaint': 'ناردنی سکاڵا',
    'exit_confirm': 'بۆ دەرچوون دووبارە دوگمەی گەڕانەوە دابگرە',

    // ─── دراوەر ───
    'user': 'بەکارهێنەر',
    'drawer_sec_emergency': 'فریاکەوتن',
    'drawer_sec_guide': 'ڕێبەر',
    'drawer_sec_manage': 'بەڕێوەبردن',
    'drawer_sec_settings': 'ڕێکخستن',
    'drawer_emergency': 'فریاکەوتن 🚑',
    'drawer_events': 'ڕووداوەکان 📅',
    'drawer_map': 'نەخشەی گەڕەکان 🗺️',
    'drawer_profile': 'پرۆفایلم 👤',
    'drawer_videos': 'ڤیدیۆ و ڕێنماییەکان 🎬',
    'drawer_gallery': 'گەلەری کەلار 📸',
    'drawer_admin': 'پانێڵی ئەدمین 👑',
    'drawer_vendor': 'پانێڵی بەڕێوەبردن 🏪',
    'drawer_admin_gallery': 'بەڕێوەبردنی گەلەری 📸',
    'drawer_settings': 'ڕێکخستنەکان ⚙️',
    'drawer_about': 'دەربارەی من 👨‍💻',
    'drawer_login': 'چوونەژوورەوە / دروستکردنی ئەکاونت',
    'drawer_logout': 'چوونەدەرەوە لە هەژمار',
    'role_admin': 'ئەدمین 👑',
    'role_vendor': 'فرۆشیار 🏪',
    'role_department': 'فەرمانگە 🏛️',
    'theme_dark': 'تاریک 🌙',
    'theme_light': 'ڕووناک ☀️',
    'logout': 'چوونەدەرەوە',
    'logout_confirm': 'دڵنیایت دەتەوێت لە هەژمارەکەت بچیتە دەرەوە؟',
    'yes_logout': 'بەڵێ، دەرچوون',
  };

  // ═══════════════════════════════════════════════════════════
  // 🌍 عەرەبی
  // ═══════════════════════════════════════════════════════════
  static const Map<String, String> _ar = {
    'app_name': 'دليل كلار',
    'app_subtitle': 'الدليل الرسمي لمدينة كلار',
    'welcome_guest': 'ضيفنا العزيز',
    'loading': 'جاري التحميل...',
    'error': 'خطأ',
    'retry': 'إعادة المحاولة',
    'ok': 'حسناً',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'delete': 'حذف',
    'edit': 'تعديل',
    'add': 'إضافة',
    'close': 'إغلاق',
    'search': 'بحث',
    'no_results': 'لا توجد نتائج',
    'no_data': 'لا توجد بيانات',
    'confirm': 'تأكيد',
    'yes': 'نعم',
    'no': 'لا',
    'next': 'التالي',
    'previous': 'السابق',
    'done': 'تم',
    'skip': 'تخطي',
    'all': 'الكل',
    'more': 'المزيد',
    'less': 'أقل',
    'see_all': 'عرض الكل',
    'updated': 'تم التحديث',
    'version': 'الإصدار',
    'language': 'اللغة',
    'required': 'مطلوب',
    'optional': 'اختياري',
    'success': 'نجح',
    'failed': 'فشل',
    'unknown_error': 'خطأ غير معروف',

    'nav_home': 'الرئيسية',
    'nav_places': 'الأماكن',
    'nav_categories': 'الأقسام',
    'nav_favorites': 'المفضلة',
    'nav_daily': 'يومي',
    'nav_search': 'بحث',
    'nav_cart': 'السلة',
    'nav_orders': 'طلباتي',
    'nav_profile': 'ملفي',
    'nav_settings': 'الإعدادات',
    'nav_videos': 'الفيديوهات',
    'nav_logout': 'تسجيل الخروج',
    'nav_login': 'تسجيل الدخول',
    'nav_admin': 'لوحة التحكم',
    'nav_emergency': 'الطوارئ',
    'nav_events': 'المناسبات',

    'stores': 'الأماكن',
    'stores_map': 'خريطة الأماكن',
    'stores_search_hint': 'ابحث عن الأماكن...',
    'stores_count': 'تم العثور على {count} مكان',
    'stores_government': 'حكومي',
    'stores_non_government': 'غير حكومي',
    'stores_all': 'الكل',
    'stores_nearest': 'الأقرب',
    'store_address': 'العنوان',
    'store_phone': 'الهاتف',
    'store_description': 'الوصف',
    'store_visit': 'زيارة',
    'store_call': 'اتصال',
    'store_whatsapp': 'واتساب',
    'store_map': 'الموقع على الخريطة',

    'cat_health': 'الصحة',
    'cat_education': 'التربية',
    'cat_higher_ed': 'التعليم العالي',
    'cat_government': 'الإدارة',
    'cat_food': 'الطعام',
    'cat_shopping': 'التسوق',

    'home_news': 'أخبار وإعلانات مهمة',
    'home_send_complaint': 'إرسال شكوى المواطنين',
    'home_complaint_subtitle': 'أرسل مشكلة أو خللاً في المدينة',
    'home_main_categories': 'الأقسام الرئيسية',
    'home_more_news': 'المزيد من الأخبار',

    'complaint_title': 'إرسال شكوى',
    'complaint_send': 'إرسال',
    'complaint_approved': 'تمت الموافقة على شكواك',
    'complaint_pending': 'قيد المراجعة',
    'complaint_resolved': 'تم الحل',

    'cart': 'السلة',
    'cart_empty': 'السلة فارغة',
    'cart_total': 'المجموع',
    'cart_checkout': 'إتمام الشراء',
    'cart_add': 'أضف إلى السلة',

    'orders': 'طلباتي',
    'orders_empty': 'لا توجد طلبات',

    'profile': 'ملفي',
    'profile_name': 'الاسم',
    'profile_phone': 'الهاتف',
    'profile_logout': 'تسجيل الخروج',

    'settings': 'الإعدادات',
    'settings_font': 'نوع الخط',
    'settings_font_size': 'حجم الخط',
    'settings_language': 'اللغة',
    'settings_theme': 'مظهر التطبيق',
    'settings_notifications': 'الإشعارات',
    'settings_preview': 'معاينة',
    'settings_reset': 'إعادة تعيين',
    'settings_theme_light': 'فاتح',
    'settings_theme_dark': 'داكن',
    'settings_theme_system': 'النظام',
    'settings_font_small': 'صغير',
    'settings_font_normal': 'عادي',
    'settings_font_large': 'كبير',
    'settings_font_xlarge': 'كبير جداً',
    'settings_reset_confirm': 'هل أنت متأكد من إعادة تعيين كل الإعدادات؟',

    'prayer_times': 'أوقات الصلاة',
    'qibla': 'القبلة',
    'qibla_finder': 'محدد القبلة',
    'weather': 'الطقس',
    'currency': 'العملات',
    'fuel': 'أسعار الوقود',

    'auth_login': 'تسجيل الدخول',
    'auth_signup': 'إنشاء حساب',
    'auth_phone': 'رقم الهاتف',
    'auth_password': 'كلمة المرور',
    'auth_name': 'الاسم الكامل',
    'auth_logout_success': 'تم تسجيل الخروج بنجاح',
    'auth_welcome_back': 'مرحباً بعودتك',
    'auth_login_failed': 'فشل تسجيل الدخول',
    'auth_invalid_phone': 'رقم الهاتف غير صالح',
    'auth_weak_password': 'كلمة المرور ضعيفة',

    // ─── الشاشة الرئيسية ───
    'menu': 'القائمة',
    'back_to_top': 'إلى الأعلى',
    'other_services': 'خدمات أخرى',
    'more_news': 'أخبار أخرى',
    'see_all_news': 'عرض كل الأخبار',
    'no_news': 'لا توجد أخبار',
    'no_more_news': 'لا توجد أخبار أخرى',
    'pull_to_refresh': 'اسحب للأسفل للتحديث',
    'neighborhoods': 'الأحياء',
    'map': 'الخريطة',
    'gallery': 'المعرض',
    'send_complaint': 'إرسال شكوى',
    'exit_confirm': 'اضغط رجوع مرة أخرى للخروج',

    // ─── القائمة الجانبية ───
    'user': 'مستخدم',
    'drawer_sec_emergency': 'الطوارئ',
    'drawer_sec_guide': 'الدليل',
    'drawer_sec_manage': 'الإدارة',
    'drawer_sec_settings': 'الإعدادات',
    'drawer_emergency': 'الطوارئ 🚑',
    'drawer_events': 'المناسبات 📅',
    'drawer_map': 'خريطة الأحياء 🗺️',
    'drawer_profile': 'ملفي الشخصي 👤',
    'drawer_videos': 'فيديوهات وإرشادات 🎬',
    'drawer_gallery': 'معرض كلار 📸',
    'drawer_admin': 'لوحة المشرف 👑',
    'drawer_vendor': 'لوحة الإدارة 🏪',
    'drawer_admin_gallery': 'إدارة المعرض 📸',
    'drawer_settings': 'الإعدادات ⚙️',
    'drawer_about': 'عن المطوّر 👨‍💻',
    'drawer_login': 'تسجيل الدخول / إنشاء حساب',
    'drawer_logout': 'تسجيل الخروج من الحساب',
    'role_admin': 'مشرف 👑',
    'role_vendor': 'بائع 🏪',
    'role_department': 'دائرة 🏛️',
    'theme_dark': 'داكن 🌙',
    'theme_light': 'فاتح ☀️',
    'logout': 'تسجيل الخروج',
    'logout_confirm': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
    'yes_logout': 'نعم، خروج',
  };

  // ═══════════════════════════════════════════════════════════
  // 🌍 ئینگلیزی
  // ═══════════════════════════════════════════════════════════
  static const Map<String, String> _en = {
    'app_name': 'Kalar Guide',
    'app_subtitle': 'Official Guide for Kalar City',
    'welcome_guest': 'Dear Guest',
    'loading': 'Loading...',
    'error': 'Error',
    'retry': 'Retry',
    'ok': 'OK',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'add': 'Add',
    'close': 'Close',
    'search': 'Search',
    'no_results': 'No results found',
    'no_data': 'No data available',
    'confirm': 'Confirm',
    'yes': 'Yes',
    'no': 'No',
    'next': 'Next',
    'previous': 'Previous',
    'done': 'Done',
    'skip': 'Skip',
    'all': 'All',
    'more': 'More',
    'less': 'Less',
    'see_all': 'See All',
    'updated': 'Updated',
    'version': 'Version',
    'language': 'Language',
    'required': 'Required',
    'optional': 'Optional',
    'success': 'Success',
    'failed': 'Failed',
    'unknown_error': 'Unknown error',

    'nav_home': 'Home',
    'nav_places': 'Places',
    'nav_categories': 'Categories',
    'nav_favorites': 'Favorites',
    'nav_daily': 'Daily',
    'nav_search': 'Search',
    'nav_cart': 'Cart',
    'nav_orders': 'My Orders',
    'nav_profile': 'Profile',
    'nav_settings': 'Settings',
    'nav_videos': 'Videos',
    'nav_logout': 'Logout',
    'nav_login': 'Login',
    'nav_admin': 'Admin Panel',
    'nav_emergency': 'Emergency',
    'nav_events': 'Events',

    'stores': 'Places',
    'stores_map': 'Map Places',
    'stores_search_hint': 'Search for places...',
    'stores_count': 'Found {count} places',
    'stores_government': 'Government',
    'stores_non_government': 'Non-Government',
    'stores_all': 'All',
    'stores_nearest': 'Nearest',
    'store_address': 'Address',
    'store_phone': 'Phone',
    'store_description': 'Description',
    'store_visit': 'Visit',
    'store_call': 'Call',
    'store_whatsapp': 'WhatsApp',
    'store_map': 'Location on Map',

    'cat_health': 'Health',
    'cat_education': 'Education',
    'cat_higher_ed': 'Higher Education',
    'cat_government': 'Government',
    'cat_food': 'Food',
    'cat_shopping': 'Shopping',

    'home_news': 'News & Important Announcements',
    'home_send_complaint': 'Send Citizen Complaint',
    'home_complaint_subtitle': 'Send an issue or problem in the city here',
    'home_main_categories': 'Main Categories',
    'home_more_news': 'More News',

    'complaint_title': 'Send Complaint',
    'complaint_send': 'Send',
    'complaint_approved': 'Your complaint was approved',
    'complaint_pending': 'Under Review',
    'complaint_resolved': 'Resolved',

    'cart': 'Cart',
    'cart_empty': 'Cart is empty',
    'cart_total': 'Total',
    'cart_checkout': 'Checkout',
    'cart_add': 'Add to Cart',

    'orders': 'My Orders',
    'orders_empty': 'No orders yet',

    'profile': 'My Profile',
    'profile_name': 'Name',
    'profile_phone': 'Phone',
    'profile_logout': 'Logout',

    'settings': 'Settings',
    'settings_font': 'Font Type',
    'settings_font_size': 'Font Size',
    'settings_language': 'Language',
    'settings_theme': 'App Theme',
    'settings_notifications': 'Notifications',
    'settings_preview': 'Preview',
    'settings_reset': 'Reset to Defaults',
    'settings_theme_light': 'Light',
    'settings_theme_dark': 'Dark',
    'settings_theme_system': 'System',
    'settings_font_small': 'Small',
    'settings_font_normal': 'Normal',
    'settings_font_large': 'Large',
    'settings_font_xlarge': 'Extra Large',
    'settings_reset_confirm':
    'Are you sure you want to reset all settings?',

    'prayer_times': 'Prayer Times',
    'qibla': 'Qibla',
    'qibla_finder': 'Qibla Finder',
    'weather': 'Weather',
    'currency': 'Currencies',
    'fuel': 'Fuel Prices',

    'auth_login': 'Login',
    'auth_signup': 'Sign Up',
    'auth_phone': 'Phone Number',
    'auth_password': 'Password',
    'auth_name': 'Full Name',
    'auth_logout_success': 'Logged out successfully',
    'auth_welcome_back': 'Welcome back',
    'auth_login_failed': 'Login failed',
    'auth_invalid_phone': 'Invalid phone number',
    'auth_weak_password': 'Password is too weak',

    // ─── Home ───
    'menu': 'Menu',
    'back_to_top': 'Back to top',
    'other_services': 'Other Services',
    'more_news': 'More News',
    'see_all_news': 'See all news',
    'no_news': 'No news yet',
    'no_more_news': 'No more news',
    'pull_to_refresh': 'Pull down to refresh',
    'neighborhoods': 'Neighborhoods',
    'map': 'Map',
    'gallery': 'Gallery',
    'send_complaint': 'Send Complaint',
    'exit_confirm': 'Press back again to exit',

    // ─── Drawer ───
    'user': 'User',
    'drawer_sec_emergency': 'Emergency',
    'drawer_sec_guide': 'Guide',
    'drawer_sec_manage': 'Management',
    'drawer_sec_settings': 'Settings',
    'drawer_emergency': 'Emergency 🚑',
    'drawer_events': 'Events 📅',
    'drawer_map': 'Neighborhood Map 🗺️',
    'drawer_profile': 'My Profile 👤',
    'drawer_videos': 'Videos & Guides 🎬',
    'drawer_gallery': 'Kalar Gallery 📸',
    'drawer_admin': 'Admin Panel 👑',
    'drawer_vendor': 'Management Panel 🏪',
    'drawer_admin_gallery': 'Manage Gallery 📸',
    'drawer_settings': 'Settings ⚙️',
    'drawer_about': 'About Me 👨‍💻',
    'drawer_login': 'Login / Create Account',
    'drawer_logout': 'Log out of account',
    'role_admin': 'Admin 👑',
    'role_vendor': 'Vendor 🏪',
    'role_department': 'Department 🏛️',
    'theme_dark': 'Dark 🌙',
    'theme_light': 'Light ☀️',
    'logout': 'Logout',
    'logout_confirm': 'Are you sure you want to log out?',
    'yes_logout': 'Yes, log out',
  };
}