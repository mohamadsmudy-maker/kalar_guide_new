import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/tr.dart';
import '../../widgets/common/optimized_network_image.dart';

/// یارمەتیدەرەکانی هەڵبژاردنی فەرمانگە لە شوێنە تۆمارکراوەکان
class DepartmentPlaces {
  DepartmentPlaces._();

  static const List<String> _govWords = [
    'فەرمانگە',
    'بەڕێوەبەرایەتی',
    'حکومی',
    'شارەوانی',
    'قایمقام',
    'ئیدارە',
    'سەرۆکایەتی',
    'دادگا',
    'پۆلیس',
  ];

  /// ئایا ئەم شوێنە فەرمانگەیەکی حکومییە؟ (جۆر، بەش یان ناو)
  static bool isGovernment(Map<String, dynamic> place) {
    final type = AppLang.normalizeKey('${place['type'] ?? ''}');
    if (type.isNotEmpty && type == AppLang.normalizeKey('حکومی')) return true;
    final text = AppLang.normalizeKey(
      '${place['category'] ?? ''} ${place['sub_category'] ?? ''} '
      '${place['name'] ?? ''}',
    );
    return _govWords.any((w) => text.contains(AppLang.normalizeKey(w)));
  }

  /// ئایا ئەم شوێنە پێشتر وەک فەرمانگە زیادکراوە؟
  static bool alreadyAdded(
    Map<String, dynamic> place,
    List<Map<String, dynamic>> departments,
  ) {
    final id = '${place['id'] ?? ''}';
    final name = AppLang.normalizeKey('${place['name'] ?? ''}');
    for (final d in departments) {
      final pid = '${d['place_id'] ?? ''}';
      if (id.isNotEmpty && pid == id) return true;
      if (name.isNotEmpty &&
          AppLang.normalizeKey('${d['name_ku'] ?? ''}') == name) {
        return true;
      }
    }
    return false;
  }

  /// ڕیزی `departments` لە شوێنێکی تۆمارکراوەوە
  static Map<String, dynamic> rowFromPlace(Map<String, dynamic> place) {
    String? clean(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return {
      'place_id': '${place['id']}',
      'name_ku': '${place['name'] ?? ''}'.trim(),
      'phone': clean(place['phone']),
      'address': clean(place['address']),
      'image': clean(place['image']),
      'color': '#10B981',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

/// 📍 لیستی شوێنە تۆمارکراوەکان — یەکێک هەڵدەبژێردرێت بۆ ئەوەی ببێتە فەرمانگە.
/// شوێنی هەڵبژێردراو دەگەڕێنێتەوە (Map) یان null.
class DepartmentPlacePickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> existingDepartments;

  /// بۆ تێست: لیستی ئامادە لەبری Supabase
  final Future<List<Map<String, dynamic>>> Function()? loader;

  const DepartmentPlacePickerSheet({
    super.key,
    required this.existingDepartments,
    this.loader,
  });

  @override
  State<DepartmentPlacePickerSheet> createState() =>
      _DepartmentPlacePickerSheetState();
}

class _DepartmentPlacePickerSheetState
    extends State<DepartmentPlacePickerSheet> {
  static const _green = Color(0xFF0F9D7A);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];
  bool _onlyGov = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final res = await Supabase.instance.client
        .from('dukan')
        .select('id, name, phone, address, image, category, sub_category, type')
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await (widget.loader ?? _fetch)();
      if (!mounted) return;
      setState(() {
        _places = list;
        // ئەگەر هیچ شوێنێکی حکومی نەبوو، هەمووی پیشان بدە
        if (!list.any(DepartmentPlaces.isGovernment)) _onlyGov = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = AppLang.normalizeKey(_query);
    return _places.where((p) {
      if (_onlyGov && !DepartmentPlaces.isGovernment(p)) return false;
      if (q.isEmpty) return true;
      final text = AppLang.normalizeKey(
        '${p['name'] ?? ''} ${p['category'] ?? ''} ${p['address'] ?? ''}',
      );
      return text.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = isDark ? Colors.white54 : const Color(0xFF8A90A0);
    final items = _visible;

    return Directionality(
      textDirection: AppLang.direction,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('هەڵبژاردنی فەرمانگە'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('لە شوێنە تۆمارکراوەکان یەکێک هەڵبژێرە'),
                          style: TextStyle(fontSize: 12, color: sub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: sub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: TextStyle(color: fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: tr('گەڕان بە ناوی شوێن...'),
                  hintStyle: TextStyle(fontSize: 13, color: sub),
                  prefixIcon: const Icon(Icons.search_rounded, color: _green),
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _chip(tr('فەرمانگە حکومییەکان'), _onlyGov, isDark,
                      () => setState(() => _onlyGov = true)),
                  const SizedBox(width: 8),
                  _chip(tr('هەموو شوێنەکان'), !_onlyGov, isDark,
                      () => setState(() => _onlyGov = false)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : _error != null
                      ? _message(
                          Icons.cloud_off_rounded,
                          tr('شوێنەکان نەهێنران'),
                          _error!,
                          sub,
                          retry: true,
                        )
                      : items.isEmpty
                          ? _message(
                              Icons.search_off_rounded,
                              tr('هیچ شوێنێک نەدۆزرایەوە'),
                              tr('سەرەتا شوێنەکە لە بەشی شوێنەکان تۆمار بکە'),
                              sub,
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                MediaQuery.paddingOf(context).bottom + 16,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) =>
                                  _tile(items[i], isDark, fg, sub),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _green
              : (isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
          ),
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> p, bool isDark, Color fg, Color sub) {
    final added =
        DepartmentPlaces.alreadyAdded(p, widget.existingDepartments);
    final name = '${p['name'] ?? ''}';
    final image = '${p['image'] ?? ''}';
    final address = '${p['address'] ?? ''}'.trim();
    final category = '${p['category'] ?? ''}'.trim();
    final line = [category, address].where((e) => e.isNotEmpty).join(' • ');

    return Opacity(
      opacity: added ? 0.55 : 1,
      child: Material(
        color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: added ? null : () => Navigator.pop(context, p),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image.isNotEmpty
                      ? OptimizedNetworkImage(
                          imageUrl: image,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: _green.withValues(alpha: 0.12),
                          child: const Icon(Icons.apartment_rounded,
                              color: _green, size: 24),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      if (line.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: sub),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                added
                    ? Text(
                        tr('زیادکراوە'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: sub,
                        ),
                      )
                    : const Icon(Icons.add_circle_rounded,
                        color: _green, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String body, Color sub,
      {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: sub),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: sub,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: sub),
            ),
            if (retry) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('دووبارە هەوڵبدەوە')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
