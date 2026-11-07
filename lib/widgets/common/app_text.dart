import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../config/translations.dart';
import '../../l10n/tr.dart';

/// 🌍 تێکستی زیرەک — بۆ تێکستە سەرەکییەکان (دەستی)
class AppText extends StatelessWidget {
  final String keyName;
  final String? fallback;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? params;

  const AppText(
      this.keyName, {
        super.key,
        this.fallback,
        this.style,
        this.textAlign,
        this.maxLines,
        this.overflow,
        this.params,
      });

  @override
  Widget build(BuildContext context) {
    // ✅ گوێ بگرە بۆ گۆڕینی زمان
    final lang = context.watch<SettingsProvider>().languageId;

    // ✅ وەرگێڕانی تێکست
    final text = params != null
        ? AppTranslations.tWithParams(keyName, lang, params!)
        : AppTranslations.t(keyName, lang);

    return Text(
      tr(// ئەگەر وەرگێڕان نەدۆزرایەوە، fallback بەکاربهێنە
      text == keyName ? (fallback ?? keyName) : text),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}