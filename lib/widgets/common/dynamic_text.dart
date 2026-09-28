import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../services/translation_service.dart';

/// 🌍 تێکستی دینامیکی — بە AI وەردەگێڕدرێت
class DynamicText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const DynamicText(
      this.text, {
        super.key,
        this.style,
        this.textAlign,
        this.maxLines,
        this.overflow,
      });

  @override
  State<DynamicText> createState() => _DynamicTextState();
}

class _DynamicTextState extends State<DynamicText> {
  String _displayed = '';
  String _currentLang = 'ku';

  @override
  void initState() {
    super.initState();
    _displayed = widget.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => _translate());
  }

  @override
  void didUpdateWidget(DynamicText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _displayed = widget.text;
      _translate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLang = context.watch<SettingsProvider>().languageId;
    if (newLang != _currentLang) {
      _currentLang = newLang;
      _translate();
    }
  }

  Future<void> _translate() async {
    // ✅ ئەگەر کوردییە، هیچ وەرگێڕانێک پێویست نییە
    if (_currentLang == 'ku') {
      if (mounted) setState(() => _displayed = widget.text);
      return;
    }

    // ✅ وەرگێڕان بە AI
    final translated = await TranslationService.translate(
      text: widget.text,
      targetLanguage: _currentLang,
    );

    if (mounted) setState(() => _displayed = translated);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayed,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}