// lib/utils/kurdish_localizations.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 🇮🇶 لۆکالایزەیشنی کوردی (سۆرانی) بۆ ویجێتەکانی Flutter — ULTRA PRO MAX V2
///
/// ✅ کۆپی/لکاندن/بڕین لە Android (پێشتر بە ئینگلیزی بوو — Material ئەمە بەکاردێنێت نەک Cupertino)
/// ✅ ڕۆژژمێر (Date picker): ناوی مانگ و ڕۆژ بە کوردی، هەفتە لە شەممەوە دەست پێدەکات
/// ✅ ژمارەکان بە کوردی (٠١٢٣)
/// ✅ لێبڵی TalkBack/VoiceOver (دیالۆگ، مێنیو، دراوەر، ...)

// ═══════════════════════════════════════════════════════════
// 🔢 Shared helpers
// ═══════════════════════════════════════════════════════════
const List<String> _kuMonths = [
  'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
  'تەممووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم',
];

/// DateTime.weekday: 1 = دووشەممە ... 7 = یەکشەممە
const List<String> _kuWeekdays = [
  'دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی', 'شەممە', 'یەکشەممە',
];

String _kuDigits(Object value) {
  const en = '0123456789';
  const ku = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in value.toString().split('')) {
    final i = en.indexOf(ch);
    b.write(i >= 0 ? ku[i] : ch);
  }
  return b.toString();
}

bool _isKurdish(Locale locale) =>
    locale.languageCode == 'ku' || locale.languageCode == 'ckb';

// ═══════════════════════════════════════════════════════════
// 🧩 Material — کوردی
// ═══════════════════════════════════════════════════════════
class KurdishMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdish(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const _KurdishMaterialLocalizations(),
      );

  @override
  bool shouldReload(KurdishMaterialLocalizationsDelegate old) => false;
}

class _KurdishMaterialLocalizations extends DefaultMaterialLocalizations {
  const _KurdishMaterialLocalizations();

  // ─── دوگمەکان ───
  @override
  String get okButtonLabel => 'باشە';
  @override
  String get cancelButtonLabel => 'پاشگەزبوونەوە';
  @override
  String get closeButtonLabel => 'داخستن';
  @override
  String get continueButtonLabel => 'بەردەوامبوون';
  @override
  String get saveButtonLabel => 'پاشەکەوت';
  @override
  String get viewLicensesButtonLabel => 'بینینی مۆڵەتەکان';
  @override
  String get licensesPageTitle => 'مۆڵەتەکان';

  // ─── Tooltips ───
  @override
  String get backButtonTooltip => 'گەڕانەوە';
  @override
  String get closeButtonTooltip => 'داخستن';
  @override
  String get deleteButtonTooltip => 'سڕینەوە';
  @override
  String get moreButtonTooltip => 'زیاتر';
  @override
  String get openAppDrawerTooltip => 'کردنەوەی مێنیو';
  @override
  String get showMenuTooltip => 'پیشاندانی لیست';
  @override
  String get nextMonthTooltip => 'مانگی داهاتوو';
  @override
  String get previousMonthTooltip => 'مانگی پێشوو';
  @override
  String get nextPageTooltip => 'لاپەڕەی داهاتوو';
  @override
  String get previousPageTooltip => 'لاپەڕەی پێشوو';
  @override
  String get firstPageTooltip => 'یەکەم لاپەڕە';
  @override
  String get lastPageTooltip => 'دوایین لاپەڕە';

  // ─── دەستکاری دەق (Android toolbar) ───
  @override
  String get copyButtonLabel => 'کۆپی';
  @override
  String get cutButtonLabel => 'بڕین';
  @override
  String get pasteButtonLabel => 'لکاندن';
  @override
  String get selectAllButtonLabel => 'هەموو هەڵبژێرە';
  @override
  String get lookUpButtonLabel => 'گەڕان';
  @override
  String get searchWebButtonLabel => 'گەڕان لە وێب';
  @override
  String get shareButtonLabel => 'هاوبەشکردن';
  @override
  String get scanTextButtonLabel => 'سکانی دەق';
  @override
  String get searchFieldLabel => 'گەڕان';

  // ─── Accessibility labels ───
  @override
  String get alertDialogLabel => 'ئاگاداری';
  @override
  String get dialogLabel => 'دیالۆگ';
  @override
  String get drawerLabel => 'مێنیوی لاتەنیشت';
  @override
  String get popupMenuLabel => 'مێنیو';
  @override
  String get bottomSheetLabel => 'پەڕەی خوارەوە';
  @override
  String get modalBarrierDismissLabel => 'داخستن';
  @override
  String get refreshIndicatorSemanticLabel => 'نوێکردنەوە';
  @override
  String get rowsPerPageTitle => 'ڕیز لە هەر لاپەڕەیەک:';

  @override
  String remainingTextFieldCharacterCount(int remaining) {
    if (remaining == 0) return 'هیچ پیتێک نەماوە';
    return '${_kuDigits(remaining)} پیت ماوە';
  }

  // ─── ڕۆژژمێر ───
  @override
  String get dateHelpText => 'بەروار هەڵبژێرە';
  @override
  String get datePickerHelpText => 'بەروار هەڵبژێرە';
  @override
  String get dateRangePickerHelpText => 'ماوە هەڵبژێرە';
  @override
  String get dateInputLabel => 'بەروار بنووسە';
  @override
  String get invalidDateFormatLabel => 'شێوازی بەروار هەڵەیە';
  @override
  String get dateOutOfRangeLabel => 'لە دەرەوەی ماوەکەیە';
  @override
  String get calendarModeButtonLabel => 'گۆڕین بۆ ڕۆژژمێر';
  @override
  String get inputDateModeButtonLabel => 'گۆڕین بۆ نووسین';
  @override
  String get unspecifiedDate => 'بەروار';
  @override
  String get currentDateLabel => 'ئەمڕۆ';

  @override
  int get firstDayOfWeekIndex => 6; // شەممە (0 = یەکشەممە)

  /// ڕیزبەندی: یەکشەممە، دووشەممە، ... شەممە
  @override
  List<String> get narrowWeekdays =>
      const ['ی', 'د', 'س', 'چ', 'پ', 'ه', 'ش'];

  @override
  String formatYear(DateTime date) => _kuDigits(date.year);

  @override
  String formatMonthYear(DateTime date) =>
      '${_kuMonths[date.month - 1]} ${_kuDigits(date.year)}';

  @override
  String formatShortMonthDay(DateTime date) =>
      '${_kuDigits(date.day)}ی ${_kuMonths[date.month - 1]}';

  @override
  String formatMediumDate(DateTime date) =>
      '${_kuWeekdays[date.weekday - 1]}، ${_kuDigits(date.day)}ی ${_kuMonths[date.month - 1]}';

  @override
  String formatFullDate(DateTime date) =>
      '${_kuWeekdays[date.weekday - 1]}، ${_kuDigits(date.day)}ی ${_kuMonths[date.month - 1]} ${_kuDigits(date.year)}';

  @override
  String formatShortDate(DateTime date) =>
      _kuDigits('${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}');

  @override
  String formatDecimal(int number) => _kuDigits(super.formatDecimal(number));

  // ─── کاتژمێر ───
  @override
  String get timePickerDialHelpText => 'کات هەڵبژێرە';
  @override
  String get timePickerInputHelpText => 'کات بنووسە';
  @override
  String get timePickerHourLabel => 'کاتژمێر';
  @override
  String get timePickerMinuteLabel => 'خولەک';
  @override
  String get timePickerHourModeAnnouncement => 'کاتژمێر هەڵبژێرە';
  @override
  String get timePickerMinuteModeAnnouncement => 'خولەک هەڵبژێرە';
  @override
  String get invalidTimeLabel => 'کاتێکی دروست بنووسە';
  @override
  String get anteMeridiemAbbreviation => 'پ.ن';
  @override
  String get postMeridiemAbbreviation => 'د.ن';
}

// ═══════════════════════════════════════════════════════════
// 🧩 Cupertino — کوردی
// ═══════════════════════════════════════════════════════════
class KurdishCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdish(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const _KurdishCupertinoLocalizations(),
      );

  @override
  bool shouldReload(KurdishCupertinoLocalizationsDelegate old) => false;
}

class _KurdishCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const _KurdishCupertinoLocalizations();

  @override
  String datePickerHourSemanticsLabel(int hour) => 'کاتژمێر ${_kuDigits(hour)}';
  @override
  String datePickerMinuteSemanticsLabel(int minute) => '${_kuDigits(minute)} خولەک';
  @override
  String datePickerMonth(int monthIndex) => _kuMonths[monthIndex - 1];
  @override
  String datePickerYear(int yearIndex) => _kuDigits(yearIndex);
  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) {
    final day = _kuDigits(dayIndex);
    if (weekDay == null) return day;
    return '${_kuWeekdays[weekDay - 1]} $day';
  }

  @override
  String get anteMeridiemAbbreviation => 'پ.ن';
  @override
  String get postMeridiemAbbreviation => 'د.ن';
  @override
  String get todayLabel => 'ئەمڕۆ';
  @override
  String get alertDialogLabel => 'ئاگاداری';
  @override
  String get searchTextFieldPlaceholderLabel => 'گەڕان';
  @override
  String get modalBarrierDismissLabel => 'داخستن';
  @override
  String get copyButtonLabel => 'کۆپی';
  @override
  String get cutButtonLabel => 'بڕین';
  @override
  String get pasteButtonLabel => 'لکاندن';
  @override
  String get selectAllButtonLabel => 'هەموو هەڵبژێرە';
}

// ═══════════════════════════════════════════════════════════
// 🧩 Widgets — کوردی
// ═══════════════════════════════════════════════════════════
class KurdishWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const KurdishWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdish(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(
        const _KurdishWidgetsLocalizations(),
      );

  @override
  bool shouldReload(KurdishWidgetsLocalizationsDelegate old) => false;
}

class _KurdishWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _KurdishWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;

  // ─── ڕیزکردنەوەی لیست (TalkBack) ───
  @override
  String get reorderItemToStart => 'گواستنەوە بۆ سەرەتا';
  @override
  String get reorderItemToEnd => 'گواستنەوە بۆ کۆتایی';
  @override
  String get reorderItemUp => 'گواستنەوە بۆ سەرەوە';
  @override
  String get reorderItemDown => 'گواستنەوە بۆ خوارەوە';
  @override
  String get reorderItemLeft => 'گواستنەوە بۆ چەپ';
  @override
  String get reorderItemRight => 'گواستنەوە بۆ ڕاست';
}
