// lib/widgets/common/dynamic_text.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import 'auto_translate.dart';

/// 🌍 تێکستی دینامیکی — بە AI وەردەگێڕدرێت (v2)
///
/// پێشتر ئەم widget ـە لۆجیکی وەرگێڕانی خۆی هەبوو (بێ cache، بێ سنوورداری،
/// و گۆڕینی زمان بە post-frame hack). ئێستا تەنها بە زمانی ئەپەوە
/// دەبەسترێتەوە و `AutoTranslate` کارەکە دەکات، بۆیە:
///  • cache ی هاوبەش لەگەڵ `AutoTranslate` (هەمان دەق دووجار وەرناگێڕدرێت)
///  • گۆڕینی زمان یەکسەر و بێ flicker
///  • ڕێکخستنی داواکارییەکان (٣ هاوکات) و cooldown ی شکست
///  • دەقی ژمارە/تەلەفۆن وەرنەگێڕدرێت
class DynamicText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// false = دەقەکە وەک خۆی نیشان بدە
  final bool translate;

  const DynamicText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.maxLines,
        this.overflow,
        this.softWrap,
        this.translate = true,
      });

  @override
  Widget build(BuildContext context) {
    // تەنها کاتێک زمان بگۆڕێت دووبارە دروست دەبێتەوە
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);

    return AutoTranslate(
      text: text,
      lang: lang,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      translate: translate,
    );
  }
}