// lib/widgets/common/auto_translate.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../services/translation_service.dart';

/// 🌐 Widget بۆ وەرگێڕانی خۆکار بەپێی زمان
class AutoTranslate extends StatefulWidget {
  final String text;
  final String lang;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  const AutoTranslate({
    super.key,
    required this.text,
    required this.lang,
    this.style,
    this.maxLines,
    this.textAlign,
  });

  @override
  State<AutoTranslate> createState() => _AutoTranslateState();
}

class _AutoTranslateState extends State<AutoTranslate> {
  String _displayed = '';
  String _currentLang = 'ku';

  @override
  void initState() {
    super.initState();
    _displayed = widget.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => _translate());
  }

  @override
  void didUpdateWidget(AutoTranslate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.lang != widget.lang) {
      _displayed = widget.text;
      _translate();
    }
  }

  Future<void> _translate() async {
    // ✅ ئەگەر کوردییە، هیچ وەرگێڕانێک پێویست نییە
    if (widget.lang == 'ku' || widget.text.isEmpty) {
      if (mounted) setState(() => _displayed = widget.text);
      return;
    }

    // ✅ وەرگێڕان بە AI
    try {
      final translated = await TranslationService.translate(
        text: widget.text,
        targetLanguage: widget.lang,
      );

      if (mounted) setState(() => _displayed = translated);
    } catch (e) {
      debugPrint('❌ AutoTranslate error: $e');
      if (mounted) setState(() => _displayed = widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayed,
      style: widget.style,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}