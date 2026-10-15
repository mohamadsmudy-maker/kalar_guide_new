import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';

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
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Neighborhood> _results = [];
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focusNode.addListener(() {
      setState(() =>
      _showResults = _focusNode.hasFocus && _results.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _results = widget.neighborhoods.where((n) {
        return n.nameKu.toLowerCase().contains(q) ||
            (n.nameAr?.toLowerCase().contains(q) ?? false) ||
            (n.nameEn?.toLowerCase().contains(q) ?? false);
      }).take(8).toList();
      _showResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Column(
        children: [
          // ─── Search Field ───
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
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
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: lang == 'ar'
                    ? 'ابحث عن حي...'
                    : (lang == 'en'
                    ? 'Search neighborhood...'
                    : 'گەڕان بۆ گەڕەک...'),
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
          if (_showResults && _results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
                itemBuilder: (_, i) {
                  final n = _results[i];

                  Color color;
                  try {
                    String hex = n.color.replaceAll('#', '');
                    if (hex.length == 6) hex = 'FF$hex';
                    color = Color(int.parse(hex, radix: 16));
                  } catch (_) {
                    color = const Color(0xFF1E88E5);
                  }

                  return ListTile(
                    leading: Icon(
                      Icons.location_city_rounded,
                      color: color,
                    ),
                    title: Text(
                      n.nameKu,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                    subtitle: Text(
                      '${n.totalStores} شوێن',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      _controller.clear();
                      _focusNode.unfocus();
                      setState(() {
                        _results = [];
                        _showResults = false;
                      });
                      widget.onSelected(n);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}