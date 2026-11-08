import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/settings_provider.dart';
import '../models/neighborhood.dart';
import '../l10n/tr.dart';

/// 📋 لیستی گەڕەکان — v2
///
///  • گەڕان لەناو لیستەکە (ناوی کوردی / عەرەبی / ئینگلیزی)
///  • کاتی کردنەوە ڕاستەوخۆ دەچێتە سەر گەڕەکی هەڵبژێردراو
///  • چاکسازی: پێشتر `current?.id == n.id` کاتێک id هەمووی null بوو هەموو
///    ئایتمەکانی وەک هەڵبژێردراو نیشان دەدا
///  • ناو بە پێی زمان، دڵخوازەکان نیشانە دەکرێن (ئارەزوومەندانە)
class NeighborhoodsDrawer extends StatefulWidget {
  final List<Neighborhood> neighborhoods;
  final Function(Neighborhood) onSelected;
  final Neighborhood? current;

  /// کلیلی گەڕەکە دڵخوازەکان (`id ?? nameKu`) — ئارەزوومەندانە
  final Set<String> favoriteKeys;

  const NeighborhoodsDrawer({
    super.key,
    required this.neighborhoods,
    required this.onSelected,
    this.current,
    this.favoriteKeys = const {},
  });

  @override
  State<NeighborhoodsDrawer> createState() => _NeighborhoodsDrawerState();
}

class _NeighborhoodsDrawerState extends State<NeighborhoodsDrawer> {
  static const double _itemExtent = 72;

  late final ScrollController _scroll;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  static const Map<String, Map<String, String>> _tr = {
    'app': {'ku': 'ڕێبەری کەلار', 'ar': 'دليل كلار', 'en': 'Kalar Guide'},
    'count': {'ku': 'گەڕەک', 'ar': 'حي', 'en': 'neighborhoods'},
    'places': {'ku': 'شوێن', 'ar': 'موقع', 'en': 'places'},
    'empty': {
      'ku': 'هیچ گەڕەکێک نییە',
      'ar': 'لا توجد أحياء',
      'en': 'No neighborhoods'
    },
    'no_match': {
      'ku': 'هیچ ئەنجامێک نەدۆزرایەوە',
      'ar': 'لا توجد نتائج',
      'en': 'No results found'
    },
    'search': {
      'ku': 'گەڕان لە لیست...',
      'ar': 'بحث في القائمة...',
      'en': 'Search the list...'
    },
  };

  @override
  void initState() {
    super.initState();
    final idx = _indexOfCurrent();
    _scroll = ScrollController(
      initialScrollOffset: idx > 1 ? (idx - 1) * _itemExtent : 0,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  String _keyOf(Neighborhood n) => n.id ?? n.nameKu;

  int _indexOfCurrent() {
    final c = widget.current;
    if (c == null) return -1;
    final k = _keyOf(c);
    return widget.neighborhoods.indexWhere((n) => _keyOf(n) == k);
  }

  /// ڕێکخستنی دەق بۆ گەڕان: ي/ی، ك/ک، ه/ە، لابردنی تەشکیل
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    String t(String k) => _tr[k]?[lang] ?? _tr[k]?['en'] ?? k;

    final all = widget.neighborhoods;
    final q = _norm(_query);

    // (ژمارەی ڕاستەقینە، گەڕەک) — ژمارە بە فلتەر ناگۆڕێت
    final items = <MapEntry<int, Neighborhood>>[
      for (int i = 0; i < all.length; i++)
        if (q.isEmpty ||
            _norm(all[i].nameKu).contains(q) ||
            _norm(all[i].nameAr ?? '').contains(q) ||
            _norm(all[i].nameEn ?? '').contains(q))
          MapEntry(i, all[i]),
    ];

    final currentKey =
    widget.current == null ? null : _keyOf(widget.current!);
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Drawer(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ───
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.map_rounded,
                        color: Colors.white, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      t('app'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_digits('${all.length}', lang)} ${t('count')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── گەڕان ───
              if (all.length > 6)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: t('search'),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                      filled: true,
                      fillColor:
                      isDark ? const Color(0xFF1A1A22) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

              // ─── لیست ───
              Expanded(
                child: all.isEmpty
                    ? _message(t('empty'), isDark)
                    : items.isEmpty
                    ? _message(t('no_match'), isDark)
                    : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemExtent: _itemExtent,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final index = items[i].key;
                    final n = items[i].value;
                    final key = _keyOf(n);
                    final selected = currentKey == key;
                    final isFav = widget.favoriteKeys.contains(key);
                    final color = n.displayColor;

                    return ListTile(
                      selected: selected,
                      selectedTileColor:
                      color.withValues(alpha: 0.12),
                      leading: CircleAvatar(
                        backgroundColor: selected
                            ? color
                            : color.withValues(alpha: 0.2),
                        child: Text(
                          tr(_digits('${index + 1}', lang)),
                          style: TextStyle(
                            color: selected ? Colors.white : color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              tr(_displayName(n, lang)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                          if (isFav) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.favorite_rounded,
                                size: 14,
                                color: Color(0xFFC2557A)),
                          ],
                        ],
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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                        widget.onSelected(n);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String text, bool isDark) => Center(
    child: Text(
      tr(text),
      style: TextStyle(
        color: isDark ? Colors.white54 : Colors.grey,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}