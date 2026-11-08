// lib/widgets/common/auto_translate.dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../services/translation_service.dart';
import '../../l10n/tr.dart';

/// 🌐 Widget بۆ وەرگێڕانی خۆکار بەپێی زمان — v2
///
/// کێشەی کۆن: لە لیستێکدا (StoreCard، هتد) هەر ئایتمێک بۆ خۆی داواکاری API
/// دەنارد، هەر جارێک سکرۆڵ بکرایە یان widget دووبارە دروست بووایەتەوە،
/// بێ cache و بێ سنوورداری.
///
/// ئێستا:
///  • cache ی LRU (٥٠٠ دەق) — جار-دووەم بێ داواکاری و بێ flicker (هاوکات لە initState)
///  • داواکاری هاوشێوە یەکدەگرنەوە (in-flight dedupe)
///  • زۆرینە ٣ داواکاری هاوکات (ڕیز)
///  • دوای شکست ٦٠ چرکە داواکاری دووبارە ناکرێتەوە بۆ هەمان دەق
///  • دەقی بێ پیت (ژمارە، تەلەفۆن) و دەقی لاتینی بۆ ئینگلیزی وەرناگێڕدرێن
///  • `translate: false` بۆ ڕێگریکردن، `overflow` / `softWrap` ی ئارەزوومەندانە
class AutoTranslate extends StatefulWidget {
  final String text;
  final String lang;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// false = دەقەکە وەک خۆی نیشان بدە
  final bool translate;

  const AutoTranslate({
    super.key,
    required this.text,
    required this.lang,
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
    this.softWrap,
    this.translate = true,
  });

  /// cache ی وەرگێڕان پاک دەکاتەوە (بۆ نموونە دوای گۆڕینی خزمەتگوزاری وەرگێڕان)
  static void clearCache() => _TranslationStore.clear();

  @override
  State<AutoTranslate> createState() => _AutoTranslateState();
}

class _AutoTranslateState extends State<AutoTranslate> {
  String _displayed = '';
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _displayed = _initialText();
    _maybeTranslate();
  }

  @override
  void didUpdateWidget(AutoTranslate old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.lang != widget.lang ||
        old.translate != widget.translate) {
      // build ی دواتر ئەم نرخە دەخوێنێتەوە — setState پێویست نییە
      _displayed = _initialText();
      _maybeTranslate();
    }
  }

  @override
  void dispose() {
    _requestId++; // وەڵامی درەنگ پشتگوێ دەخرێت
    super.dispose();
  }

  /// وەرگێڕانی ئامادەی ناو ئەپ (lib/l10n/strings) — خێرا و بێ سێرڤەر
  String? get _bundled => AppLang.lookup(widget.lang, widget.text);

  bool get _needsTranslation =>
      widget.translate && _bundled == null && _shouldTranslate(widget.text, widget.lang);

  /// cache → هاوکات و بێ flicker؛ ئەگەرنا دەقی ڕەسەن
  String _initialText() {
    if (widget.translate && widget.lang != 'ku' && _bundled != null) return _bundled!;
    if (!_needsTranslation) return widget.text;
    return _TranslationStore.get(widget.lang, widget.text) ??
        TranslationService.cachedOrNull(widget.text, widget.lang) ??
        widget.text;
  }

  Future<void> _maybeTranslate() async {
    if (!_needsTranslation) return;
    if (_TranslationStore.get(widget.lang, widget.text) != null) return;
    if (TranslationService.cachedOrNull(widget.text, widget.lang) != null) return;

    final requestId = ++_requestId;
    final text = widget.text;
    final lang = widget.lang;

    final translated = await _TranslationStore.fetch(text, lang);

    // تەنها ئەگەر ئەم داواکارییە هێشتا نوێترین بێت
    if (!mounted || requestId != _requestId) return;
    if (translated != null && translated != _displayed) {
      setState(() => _displayed = translated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      tr(_displayed),
      style: widget.style,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
      softWrap: widget.softWrap,
      overflow: widget.overflow ??
          (widget.maxLines != null ? TextOverflow.ellipsis : null),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🧠 هەڵبژاردنی دەقی پێویست بە وەرگێڕان
// ═══════════════════════════════════════════════════════════
final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _hasArabicScript = RegExp(r'[\u0600-\u06FF]');

bool _shouldTranslate(String text, String lang) {
  if (lang == 'ku' || text.trim().isEmpty) return false; // سەرچاوە = کوردی
  if (!_hasLetter.hasMatch(text)) return false; // ژمارە / هێما / تەلەفۆن
  // ئینگلیزی: ئەگەر هیچ پیتی کوردی/عەرەبی نییە، پێشتر ئینگلیزییە
  if (lang == 'en' && !_hasArabicScript.hasMatch(text)) return false;
  return true;
}

// ═══════════════════════════════════════════════════════════
// 💾 cache + ڕیزی داواکاری
// ═══════════════════════════════════════════════════════════
class _TranslationStore {
  _TranslationStore._();

  static const int _maxEntries = 500;
  static const int _maxConcurrent = 3;
  static const Duration _failCooldown = Duration(seconds: 60);

  static final LinkedHashMap<String, String> _cache = LinkedHashMap();
  static final Map<String, Future<String?>> _inFlight = {};
  static final Map<String, DateTime> _failedAt = {};

  static int _running = 0;
  static final Queue<Completer<void>> _waiting = Queue();

  static String _key(String lang, String text) => '$lang\u0000$text';

  static String? get(String lang, String text) {
    final k = _key(lang, text);
    final v = _cache.remove(k);
    if (v != null) _cache[k] = v; // نوێترین = کۆتایی
    return v;
  }

  static void _put(String k, String v) {
    _cache.remove(k);
    _cache[k] = v;
    if (_cache.length > _maxEntries) _cache.remove(_cache.keys.first);
  }

  static void clear() {
    _cache.clear();
    _failedAt.clear();
  }

  /// null = وەرگێڕان نەکرا (دەقی ڕەسەن بمێنێتەوە)
  static Future<String?> fetch(String text, String lang) {
    final k = _key(lang, text);

    final cached = get(lang, text);
    if (cached != null) return Future.value(cached);

    final failed = _failedAt[k];
    if (failed != null && DateTime.now().difference(failed) < _failCooldown) {
      return Future.value(null);
    }

    return _inFlight[k] ??= _run(text, lang, k).whenComplete(() {
      _inFlight.remove(k);
    });
  }

  static Future<String?> _run(String text, String lang, String k) async {
    // ─── ڕیز: زۆرینە _maxConcurrent هاوکات ───
    if (_running >= _maxConcurrent) {
      final gate = Completer<void>();
      _waiting.add(gate);
      await gate.future;
    }
    _running++;

    try {
      final result = await TranslationService.translate(
        text: text,
        targetLanguage: lang,
      );
      final cleaned = result.trim();
      if (cleaned.isEmpty) {
        _failedAt[k] = DateTime.now();
        return null;
      }
      _failedAt.remove(k);
      _put(k, cleaned);
      return cleaned;
    } catch (e) {
      debugPrint('❌ AutoTranslate error: $e');
      _failedAt[k] = DateTime.now();
      return null;
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeFirst().complete();
    }
  }
}