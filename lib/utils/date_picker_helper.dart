import 'package:flutter/material.dart';

/// 📅 یاریدەدەر بۆ Date Picker بەپێی زمان
class DatePickerHelper {
  DatePickerHelper._();

  /// 🌍 وەرگرتنی Locale بەپێی کۆدی زمان
  static Locale getLocaleForLanguage(String languageId) {
    switch (languageId) {
      case 'ar':
        return const Locale('ar', 'AE');
      case 'en':
        return const Locale('en', 'US');
      case 'ku':
      default:
      // ✅ کوردی — بەکارهێنانی عەرەبی وەک بنەڕەت
        return const Locale('ar', 'AE');
    }
  }

  /// 🔄 وەرگرتنی ئاراستە بەپێی زمان
  static TextDirection getDirectionForLanguage(String languageId) {
    return languageId == 'en' ? TextDirection.ltr : TextDirection.rtl;
  }

  /// 📅 پیشاندانی Date Range Picker بەپێی زمان
  static Future<DateTimeRange?> showRangePicker({
    required BuildContext context,
    required String languageId,
    required DateTime initialFrom,
    required DateTime initialTo,
    required Color primaryColor,
  }) async {
    final locale = getLocaleForLanguage(languageId);
    final direction = getDirectionForLanguage(languageId);

    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: initialFrom,
        end: initialTo,
      ),
      locale: locale,
      builder: (context, child) {
        return Directionality(
          textDirection: direction,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
  }

  /// 📅 پیشاندانی Single Date Picker
  static Future<DateTime?> showSingleDatePicker({
    required BuildContext context,
    required String languageId,
    required DateTime initialDate,
    required Color primaryColor,
  }) async {
    final locale = getLocaleForLanguage(languageId);
    final direction = getDirectionForLanguage(languageId);

    return showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: initialDate,
      locale: locale,
      builder: (context, child) {
        return Directionality(
          textDirection: direction,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
  }

  /// 📅 پیشاندانی Time Picker
  static Future<TimeOfDay?> showTimePickerCustom({
    required BuildContext context,
    required String languageId,
    required TimeOfDay initialTime,
  }) async {
    final direction = getDirectionForLanguage(languageId);

    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Directionality(
          textDirection: direction,
          child: child!,
        );
      },
    );
  }
}