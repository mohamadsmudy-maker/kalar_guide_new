import 'package:flutter/material.dart';
import '../../services/translation_service.dart';

/// 🌍 ویجێتی وەرگێڕانی خۆکار بۆ داتای داتابەیس
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

  @override
  void initState() {
    super.initState();
    _displayed = widget.text;
    _load();
  }

  @override
  void didUpdateWidget(AutoTranslate old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.lang != widget.lang) {
      _load();
    }
  }

  Future<void> _load() async {
    // ✅ کوردی = هیچ وەرگێڕانێک پێویست نییە
    if (widget.lang == 'ku' || widget.text.trim().isEmpty) {
      if (mounted) {
        setState(() => _displayed = widget.text);
      }
      return;
    }

    // نمایشکردنی دەقی سەرەکی بە کاڵی تا وەرگێڕان
    if (mounted) {
      setState(() {
        _loading = true;
        _displayed = widget.text;
      });
    }

    final translated = await TranslationService.translate(
      text: widget.text,
      targetLanguage: widget.lang,
    );

    if (mounted) {
      setState(() {
        _displayed = translated;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _loading ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        _displayed,
        style: widget.style,
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
        overflow: widget.overflow ?? TextOverflow.ellipsis,
      ),
    );
  }
}