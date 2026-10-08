import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../services/translation_service.dart';

/// 🌍 ویجێتی وەرگێڕانی خۆکار بۆ داتای داتابەیس
/// ✅ چاککراو — پشتگیری گۆڕینی زمان بە دروستی
class AutoTranslate extends StatefulWidget {
  final String text;
  final String lang;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  const AutoTranslate({
    super.key,
    required this.text,
    required this.lang,
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
  });

  @override
  State<AutoTranslate> createState() => _AutoTranslateState();
}

class _AutoTranslateState extends State<AutoTranslate> {
  String _displayed = '';
  bool _loading = false;
  bool _isTranslated = false;

  @override
  void initState() {
    super.initState();
    _displayed = widget.text;
    _load();
  }

  @override
  void didUpdateWidget(AutoTranslate old) {
    super.didUpdateWidget(old);
    // ✅ دوای هەر گۆڕانکاری text یان lang، دووبارە بار بکە
    if (old.text != widget.text || old.lang != widget.lang) {
      _displayed = widget.text;
      _isTranslated = false;
      _load();
    }
  }

  Future<void> _load() async {
    final text = widget.text.trim();
    final lang = widget.lang;

    // ✅ کوردی = هیچ وەرگێڕانێک پێویست نییە
    if (lang == 'ku' || text.isEmpty) {
      if (mounted) {
        setState(() {
          _displayed = widget.text;
          _loading = false;
          _isTranslated = false;
        });
      }
      return;
    }

    // ✅ نمایشکردنی دەقی سەرەکی تا وەرگێڕان
    if (mounted) {
      setState(() {
        _loading = true;
        _displayed = widget.text;
      });
    }

    try {
      final translated = await TranslationService.translate(
        text: text,
        targetLanguage: lang,
        sourceLanguage: 'ku',
      );

      if (mounted) {
        setState(() {
          _displayed = translated.isEmpty ? widget.text : translated;
          _loading = false;
          _isTranslated = translated != widget.text;
        });
      }
    } catch (e) {
      debugPrint('❌ AutoTranslate error: $e');
      if (mounted) {
        setState(() {
          _displayed = widget.text;
          _loading = false;
          _isTranslated = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ watch کردنی زمان — بۆ ئەوەی کاتێک گۆڕدرا، didUpdateWidget بانگ بکرێت
    final currentLang = context.watch<SettingsProvider>().languageId;

    return AnimatedOpacity(
      opacity: _loading ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        _displayed,
        style: widget.style?.copyWith(
          fontStyle: _isTranslated && _loading ? FontStyle.italic : null,
        ),
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
        overflow: widget.overflow ?? TextOverflow.ellipsis,
        // ✅ هەروەها زمان لە خۆیدا biheshêle
        key: ValueKey('$currentLang-${widget.text}'),
      ),
    );
  }
}