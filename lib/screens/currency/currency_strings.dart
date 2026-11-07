import '../../services/currency_service.dart';

/// 🌐 دەقەکانی بەشی دراو — کوردی / عەرەبی / ئینگلیزی
class CurrencyStrings {
  CurrencyStrings._();

  static const Map<String, Map<String, String>> _t = {
    'title': {'ku': 'نرخی دراو و زێڕ', 'ar': 'أسعار العملات والذهب', 'en': 'Currency & Gold'},
    'best_sell': {'ku': 'هەرزانترین فرۆشتن', 'ar': 'أرخص بيع', 'en': 'Best sell'},
    'best_buy': {'ku': 'بەرزترین کڕین', 'ar': 'أعلى شراء', 'en': 'Best buy'},
    'sell': {'ku': 'فرۆشتن', 'ar': 'بيع', 'en': 'Sell'},
    'buy': {'ku': 'کڕین', 'ar': 'شراء', 'en': 'Buy'},
    'avg': {'ku': 'تێکڕا', 'ar': 'المعدل', 'en': 'Average'},
    'spread': {'ku': 'جیاوازی', 'ar': 'الفرق', 'en': 'Spread'},
    'per': {'ku': 'بۆ هەر', 'ar': 'لكل', 'en': 'per'},
    'iqd': {'ku': 'دینار', 'ar': 'دينار', 'en': 'IQD'},
    'stations': {'ku': 'نوسینگە', 'ar': 'مكتب', 'en': 'offices'},
    'live': {'ku': 'ڕاستەوخۆ', 'ar': 'مباشر', 'en': 'Live'},
    'updated': {'ku': 'نوێکرایەوە', 'ar': 'تم التحديث', 'en': 'Updated'},
    'no_prices': {'ku': 'هیچ نرخێک نییە', 'ar': 'لا توجد أسعار', 'en': 'No prices yet'},
    'no_data': {'ku': 'هیچ داتایەک نییە', 'ar': 'لا توجد بيانات', 'en': 'No data'},
    'all': {'ku': 'هەموو', 'ar': 'الكل', 'en': 'All'},
    'fiat': {'ku': 'دراوەکان', 'ar': 'العملات', 'en': 'Currencies'},
    'gold': {'ku': 'زێڕ', 'ar': 'الذهب', 'en': 'Gold'},
    'markets': {'ku': 'بازاڕی ئەمڕۆ', 'ar': 'سوق اليوم', 'en': "Today's market"},
    'chart': {'ku': 'چارتی گۆڕانکارییەکان', 'ar': 'مخطط التغيرات', 'en': 'Price changes'},
    'pdf': {'ku': 'ڕاپۆرتی PDF', 'ar': 'تقرير PDF', 'en': 'PDF report'},
    'global_chart': {'ku': 'چارتی گشتی', 'ar': 'المخطط العام', 'en': 'Full chart'},
    'no_history': {'ku': 'هیچ مێژوویەک نییە', 'ar': 'لا يوجد سجل', 'en': 'No history yet'},
    'converter': {'ku': 'گۆڕینەوەی خێرا', 'ar': 'محول سريع', 'en': 'Quick converter'},
    'i_buy': {'ku': 'دەکڕم', 'ar': 'أشتري', 'en': 'I buy'},
    'i_sell': {'ku': 'دەفرۆشم', 'ar': 'أبيع', 'en': 'I sell'},
    'amount': {'ku': 'بڕ', 'ar': 'المبلغ', 'en': 'Amount'},
    'you_pay': {'ku': 'دەدەیت', 'ar': 'تدفع', 'en': 'You pay'},
    'you_get': {'ku': 'وەردەگریت', 'ar': 'تستلم', 'en': 'You get'},
    'at': {'ku': 'لە', 'ar': 'في', 'en': 'at'},
    'copied': {'ku': 'کۆپی کرا', 'ar': 'تم النسخ', 'en': 'Copied'},
    'sort_sell': {'ku': 'بۆ کڕین', 'ar': 'للشراء', 'en': 'To buy'},
    'sort_buy': {'ku': 'بۆ فرۆشتن', 'ar': 'للبيع', 'en': 'To sell'},
    'sort_recent': {'ku': 'نوێترین', 'ar': 'الأحدث', 'en': 'Newest'},
    'search': {'ku': 'گەڕان بە ناوی نوسینگە...', 'ar': 'ابحث باسم المكتب...', 'en': 'Search offices...'},
    'best': {'ku': 'باشترین', 'ar': 'الأفضل', 'en': 'Best'},
    'call': {'ku': 'پەیوەندی', 'ar': 'اتصال', 'en': 'Call'},
    'share': {'ku': 'هاوبەشکردن', 'ar': 'مشاركة', 'en': 'Share'},
    'edit_price': {'ku': 'نوێکردنەوەی نرخ', 'ar': 'تحديث السعر', 'en': 'Update price'},
    'details': {'ku': 'وردەکاری', 'ar': 'التفاصيل', 'en': 'Details'},
    'offices_of': {'ku': 'نوسینگەکانی', 'ar': 'مكاتب', 'en': 'Offices for'},
    'no_offices': {'ku': 'هیچ نوسینگەیەک نییە بۆ', 'ar': 'لا توجد مكاتب لـ', 'en': 'No offices for'},
    'current_prices': {'ku': 'نرخەکانی ئێستا', 'ar': 'الأسعار الحالية', 'en': 'Current prices'},
    'history': {'ku': 'مێژووی نرخەکان', 'ar': 'سجل الأسعار', 'en': 'Price history'},
    'see_all': {'ku': 'هەمووی', 'ar': 'عرض الكل', 'en': 'See all'},
    'not_found': {'ku': 'نوسینگە نەدۆزرایەوە', 'ar': 'لم يتم العثور على المكتب', 'en': 'Office not found'},
    'cancel': {'ku': 'پاشگەزبوونەوە', 'ar': 'إلغاء', 'en': 'Cancel'},
    'save': {'ku': 'پاشەکەوتکردن', 'ar': 'حفظ', 'en': 'Save'},
    'saved': {'ku': 'نرخ نوێکرایەوە', 'ar': 'تم تحديث السعر', 'en': 'Price updated'},
    'save_failed': {'ku': 'پاشەکەوت نەکرا، دووبارە هەوڵ بدەرەوە', 'ar': 'فشل الحفظ، حاول مجدداً', 'en': 'Save failed, try again'},
    'invalid': {'ku': 'تکایە لانیکەم یەک نرخی دروست بنووسە', 'ar': 'أدخل سعراً صحيحاً واحداً على الأقل', 'en': 'Enter at least one valid price'},
    'buy_gt_sell': {'ku': 'نرخی کڕین نابێت لە فرۆشتن زیاتر بێت', 'ar': 'سعر الشراء لا يجب أن يتجاوز البيع', 'en': 'Buy price should not exceed sell price'},
    'notes': {'ku': 'تێبینی (ئارەزوومەندانە)', 'ar': 'ملاحظة (اختياري)', 'en': 'Note (optional)'},
    'add_price': {'ku': 'زیادکردنی دراو', 'ar': 'إضافة عملة', 'en': 'Add currency'},
    'no_permission': {'ku': 'دەسەڵاتی دەستکاریکردنت نییە', 'ar': 'ليس لديك صلاحية التعديل', 'en': 'You cannot edit this office'},
    'just_now': {'ku': 'ئێستا', 'ar': 'الآن', 'en': 'just now'},
    'min_ago': {'ku': '{n} خولەک لەمەوبەر', 'ar': 'قبل {n} دقيقة', 'en': '{n} min ago'},
    'hour_ago': {'ku': '{n} کاتژمێر لەمەوبەر', 'ar': 'قبل {n} ساعة', 'en': '{n} h ago'},
    'day_ago': {'ku': '{n} ڕۆژ لەمەوبەر', 'ar': 'قبل {n} يوم', 'en': '{n} d ago'},
    'stale': {'ku': 'کۆنە', 'ar': 'قديم', 'en': 'old'},
    'error': {'ku': 'هەڵەیەک ڕوویدا', 'ar': 'حدث خطأ', 'en': 'Something went wrong'},
    'retry': {'ku': 'دووبارە هەوڵ بدەرەوە', 'ar': 'أعد المحاولة', 'en': 'Retry'},
  };

  static String of(String lang, String key) {
    final row = _t[key];
    if (row == null) return key;
    return row[lang] ?? row['ku'] ?? key;
  }

  /// "٥ خولەک لەمەوبەر"
  static String timeAgo(DateTime? date, String lang) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date.toLocal());
    String fill(String k, int n) =>
        of(lang, k).replaceAll('{n}', CurrencyService.localizeDigits('$n', lang));

    if (diff.inMinutes < 1) return of(lang, 'just_now');
    if (diff.inHours < 1) return fill('min_ago', diff.inMinutes);
    if (diff.inDays < 1) return fill('hour_ago', diff.inHours);
    return fill('day_ago', diff.inDays);
  }

  /// نرخێک کە زیاتر لە ٢ ڕۆژ نوێ نەکرابێتەوە
  static bool isStale(DateTime? date) =>
      date != null && DateTime.now().difference(date.toLocal()).inHours >= 48;
}
