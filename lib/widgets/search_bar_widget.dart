import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../models/neighborhood.dart';

/// 🔎 خانەی گەڕان بۆ گەڕەک — v2
///
///  • ڕێکخستنی پیت: ي/ی، ك/ک، ه/ە و لابردنی تەشکیل — «کەلار» و «كلار» هەردووکیان دەدۆزرێتەوە
///  • ڕیزبەندی ئەنجام: ئەوانەی بە پیتی گەڕان دەستپێدەکەن پێشتر
///  • Enter = یەکەم ئەنجام هەڵدەبژێرێت
///  • کاتێک لیستی گەڕەکان دواتر بار دەبێت (didUpdateWidget) ئەنجامەکان نوێ دەبنەوە
///  • «هیچ ئەنجامێک نییە» نیشان دەدرێت (پێشتر هیچ نەدەبوو)
///  • ناو بە پێی زمان
class SearchBarWidget extends StatefulWidget {
  final List<Neighborhood> neighborhoods;
  final Function(Neighborhood) onSelected;

  const SearchBarWidget({
    super.key,
    required this.neighborhoods,
    required this.onSelected,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  static const int _maxResults = 8;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Neighborhood> _results = const [];
  bool _hasFocus = false;

  static const Map<String, Map<String, String>> _tr = {
    'hint': {
      'ku': 'گەڕان بۆ گەڕەک...',
      'ar': 'ابحث عن حي...',
      'en': 'Search neighborhood...'
    },
    'places': {'ku': 'شوێن', 'ar': 'موقع', 'en': 'places'},
    'none': {
      'ku': 'هیچ ئەنجامێک نەدۆزرایەوە',
      'ar': 'لا توجد نتائج',
      'en': 'No results found'
    },
    'clear': {'ku': 'سڕینەوە', 'ar': 'مسح', 'en': 'Clear'},
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant SearchBarWidget old) {
    super.didUpdateWidget(old);
    if (!identical(old.neighborhoods, widget.neighborhoods) &&
        _controller.text.trim().isNotEmpty) {
      _results = _search(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔎 Search
  // ═══════════════════════════════════════════════════════════
  String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp('[\u064B-\u065F\u0640\u200C\u200D]'), '')
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ە', 'ه')
        .trim();
  }

  List<Neighborhood> _search(String raw) {
    final q = _norm(raw);
    if (q.isEmpty) return const [];

    final starts = <Neighborhood>[];
    final contains = <Neighborhood>[];

    for (final n in widget.neighborhoods) {
      final names = [
        _norm(n.nameKu),
        _norm(n.nameAr ?? ''),
        _norm(n.nameEn ?? ''),
      ];
      if (names.any((s) => s.startsWith(q))) {
        starts.add(n);
      } else if (names.any((s) => s.contains(q))) {
        contains.add(n);
      }
    }
    return [...starts, ...contains].take(_maxResults).toList();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _results = _search(_controller.text));
  }

  void _select(Neighborhood n) {
    HapticFeedback.selectionClick();
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _results = const []);
    widget.onSelected(n);
  }

  String _displayName(Neighborhood n, String lang) {
    final ar = n.nameAr?.trim() ?? '';
    final en = n.nameEn?.trim() ?? '';
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return n.nameKu;
  }

  String _digits(String s, String lang) {
    if (lang == 'en') return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      s = s.replaceAll(en[i], ar[i]);
    }
    return s;
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    String t(String k) => _tr[k]?[lang] ?? _tr[k]?['en'] ?? k;

    final hasQuery = _controller.text.trim().isNotEmpty;
    final showPanel = _hasFocus && hasQuery;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final surface = isDark ? const Color(0xFF1A1A22) : Colors.white;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Search field ───
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                if (_results.isNotEmpty) _select(_results.first);
              },
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: t('hint'),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1E88E5),
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                  tooltip: t('clear'),
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _focusNode.unfocus();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          // ─── ئەنجامەکان ───
          if (showPanel)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _results.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        t('none'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                          isDark ? Colors.white54 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color:
                    isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                  itemBuilder: (_, i) {
                    final n = _results[i];
                    final color = n.displayColor;

                    return ListTile(
                      leading: Icon(Icons.location_city_rounded,
                          color: color),
                      title: Text(
                        _displayName(n, lang),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: fg,
                        ),
                      ),
                      subtitle: Text(
                        '${_digits('${n.totalStores}', lang)} ${t('places')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                      ),
                      onTap: () => _select(n),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}