// lib/utils/date_picker_helper.dart
import 'package:flutter/material.dart';

/// 📅 یاریدەدەر بۆ Date Picker بەپێی زمان
class DatePickerHelper {
  DatePickerHelper._();

  // ═══════════════════════════════════════════════════════════
  // 🌍 Locale
  // ═══════════════════════════════════════════════════════════
  static Locale getLocaleForLanguage(String languageId) {
    switch (languageId) {
      case 'ar':
        return const Locale('ar', 'AE');
      case 'en':
        return const Locale('en', 'US');
      case 'ku':
      default:
        return const Locale('ar', 'AE');
    }
  }

  static TextDirection getDirectionForLanguage(String languageId) {
    return languageId == 'en' ? TextDirection.ltr : TextDirection.rtl;
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 Range Picker
  // ═══════════════════════════════════════════════════════════
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
              colorScheme: Theme.of(context).colorScheme.copyWith(
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

  // ═══════════════════════════════════════════════════════════
  // 📅 Single Picker
  // ═══════════════════════════════════════════════════════════
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
              colorScheme: Theme.of(context).colorScheme.copyWith(
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

  // ═══════════════════════════════════════════════════════════
  // ⏰ Time Picker
  // ═══════════════════════════════════════════════════════════
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