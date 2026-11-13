import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/currency_service.dart';
import '../../services/fuel_service.dart';
import '../../services/price_types.dart';

/// پاشەکەوتکردنی جۆرەکان — لە تێستدا دەگۆڕدرێت
abstract class PriceTypesStore {
  Future<List<Map<String, dynamic>>> fetch(PriceKind kind);
  Future<void> insert(Map<String, dynamic> row);
  Future<void> update(dynamic id, Map<String, dynamic> row);
  Future<void> delete(dynamic id);
  Future<void> saveOrder(List<dynamic> orderedIds);
  Future<void> restoreDefaults(PriceKind kind);
}

class _SupabaseStore implements PriceTypesStore {
  const _SupabaseStore();

  @override
  Future<List<Map<String, dynamic>>> fetch(PriceKind kind) =>
      PriceTypes.fetchRows(kind);
  @override
  Future<void> insert(Map<String, dynamic> row) => PriceTypes.insert(row);
  @override
  Future<void> update(dynamic id, Map<String, dynamic> row) =>
      PriceTypes.update(id, row);
  @override
  Future<void> delete(dynamic id) => PriceTypes.delete(id);
  @override
  Future<void> saveOrder(List<dynamic> orderedIds) =>
      PriceTypes.saveOrder(orderedIds);
  @override
  Future<void> restoreDefaults(PriceKind kind) {
    final defaults = kind == PriceKind.fuel
        ? FuelService.defaultFuelTypes
        : CurrencyService.defaultCurrencyTypes;
    return PriceTypes.insertMany([
      for (var i = 0; i < defaults.length; i++)
        PriceTypes.rowFromDefault(kind, defaults[i], i + 1),
    ]);
  }
}

/// ⛽ بەڕێوەبردنی جۆرەکانی سووتەمەنی / دراو:
/// زیادکردن، دەستکاری، سڕینەوە، و ڕیزکردن بە ڕاکێشان (دراگ و دڕۆپ).
class AdminPriceTypesScreen extends StatefulWidget {
  final PriceKind kind;
  final PriceTypesStore store;

  const AdminPriceTypesScreen({
    super.key,
    required this.kind,
    this.store = const _SupabaseStore(),
  });

  @override
  State<AdminPriceTypesScreen> createState() => _AdminPriceTypesScreenState();
}

class _AdminPriceTypesScreenState extends State<AdminPriceTypesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  bool get _isFuel => widget.kind == PriceKind.fuel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.store.fetch(widget.kind);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ↕️ ڕیزکردن
  // ═══════════════════════════════════════════════════════════
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final before = List<Map<String, dynamic>>.from(_rows);
    setState(() {
      final item = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, item);
    });
    HapticFeedback.selectionClick();
    try {
      await widget.store.saveOrder([for (final r in _rows) r['id']]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _rows = before);
      _snack(trf('هەڵە: {0}', [e]), error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ / ✏️ زیادکردن و دەستکاری
  // ═══════════════════════════════════════════════════════════
  Future<void> _openEditor({Map<String, dynamic>? row}) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceTypeEditor(kind: widget.kind, row: row),
    );
    if (data == null) return;

    try {
      if (row == null) {
        final taken = {for (final r in _rows) '${r['key']}'};
        data['key'] = PriceTypes.makeKey(
            '${data['name_en'] ?? ''}', '${data['name_ku']}', taken);
        data['kind'] = widget.kind.db;
        data['sort_order'] = _rows.length + 1;
        await widget.store.insert(data);
      } else {
        await widget.store.update(row['id'], data);
      }
      await _load();
      if (mounted) _snack(tr('✅ پاشەکەوتکرا'));
    } catch (e) {
      if (mounted) _snack(trf('هەڵە: {0}', [e]), error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('سڕینەوەی جۆر')),
          content: Text(trf(
            'ئایا دڵنیایت لە سڕینەوەی "{0}"؟\n\nنرخە پاشەکەوتکراوەکانی بەنزینخانەکان و نوسینگەکان دەمێننەوە، بەڵام ئەم جۆرە چیتر پیشان نادرێت.',
            ['${row['name_ku']}'],
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.store.delete(row['id']);
      if (!mounted) return;
      setState(() => _rows.removeWhere((r) => r['id'] == row['id']));
      HapticFeedback.mediumImpact();
      _snack(tr('✅ جۆرەکە سڕایەوە'));
    } catch (e) {
      if (mounted) _snack(trf('هەڵە: {0}', [e]), error: true);
    }
  }

  Future<void> _restore() async {
    try {
      await widget.store.restoreDefaults(widget.kind);
      await _load();
    } catch (e) {
      if (mounted) _snack(trf('هەڵە: {0}', [e]), error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕواڵەت
  // ═══════════════════════════════════════════════════════════
  static Color _hex(String? hex, [Color fallback = AppColors.primary]) {
    try {
      var h = (hex ?? '').replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = isDark ? Colors.white54 : const Color(0xFF8A90A0);

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1B2E) : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            tr(_isFuel ? 'جۆرەکانی سووتەمەنی' : 'جۆرەکانی دراو'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
                ? _message(
                    Icons.cloud_off_rounded,
                    tr('جۆرەکان نەهێنران'),
                    '${tr('ئەگەر مایگرەیشنی 20261118_price_types.sql جێبەجێ نەکراوە، لە Supabase جێبەجێی بکە')}\n\n$_error',
                    fg,
                    sub,
                    retry: true,
                  )
                : _rows.isEmpty
                    ? _message(
                        Icons.format_list_bulleted_rounded,
                        tr('هیچ جۆرێک نییە'),
                        tr('جۆری نوێ زیاد بکە یان جۆرە سەرەکییەکان بگەڕێنەرەوە'),
                        fg,
                        sub,
                        restore: true,
                      )
                    : _buildList(isDark, fg, sub),
        floatingActionButton: _error != null
            ? null
            : FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  tr('جۆری نوێ'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
      ),
    );
  }

  Widget _buildList(bool isDark, Color fg, Color sub) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('دەستگرەکە (≡) بگرە و ڕایبکێشە بۆ گۆڕینی ڕیز. ئەم ڕیزە لە هەموو شوێنێکی ئەپ بەکاردێت.'),
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: fg),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            buildDefaultDragHandles: false,
            itemCount: _rows.length,
            onReorderItem: _onReorder,
            proxyDecorator: (child, i, anim) => Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
            itemBuilder: (context, i) => _card(i, isDark, fg, sub),
          ),
        ),
      ],
    );
  }

  Widget _card(int i, bool isDark, Color fg, Color sub) {
    final r = _rows[i];
    final color = _hex('${r['color']}');
    final emoji = '${r['emoji'] ?? ''}'.trim();
    final unit = '${r['unit_ku'] ?? ''}'.trim();
    final grp = '${r['grp'] ?? ''}';
    final grpLabel = switch (grp) {
      'gas' => tr('گاز'),
      'fuel' => tr('سووتەمەنی'),
      'gold' => tr('زێڕ'),
      'fiat' => tr('دراو'),
      _ => grp,
    };
    final per = (r['per'] as num?) ?? 1;
    final subtitle = [
      grpLabel,
      if (unit.isNotEmpty) unit,
      if (!_isFuel && per != 1) trf('بۆ {0}', ['$per']),
    ].join(' • ');

    return Container(
      key: ValueKey(r['id']),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.25 : 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: emoji.isEmpty
                  ? Icon(Icons.local_gas_station_rounded, color: color)
                  : Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['name_ku']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800, color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: sub),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr('دەستکاری'),
              icon: const Icon(Icons.edit_rounded,
                  size: 20, color: AppColors.primary),
              onPressed: () => _openEditor(row: r),
            ),
            IconButton(
              tooltip: tr('سڕینەوە'),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Color(0xFFDC3545)),
              onPressed: () => _delete(r),
            ),
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Icon(Icons.drag_handle_rounded, color: sub, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String body, Color fg, Color sub,
      {bool retry = false, bool restore = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: sub),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: sub)),
            if (retry)
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('دووبارە هەوڵبدەوە')),
              ),
            if (restore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(tr('گەڕاندنەوەی جۆرە سەرەکییەکان')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📝 فۆرمی جۆر
// ═══════════════════════════════════════════════════════════
class _PriceTypeEditor extends StatefulWidget {
  final PriceKind kind;
  final Map<String, dynamic>? row;

  const _PriceTypeEditor({required this.kind, this.row});

  @override
  State<_PriceTypeEditor> createState() => _PriceTypeEditorState();
}

class _PriceTypeEditorState extends State<_PriceTypeEditor> {
  static const _palette = [
    '#1E88E5', '#EF4444', '#F59E0B', '#14B8A6', '#10B981',
    '#8B5CF6', '#EC4899', '#6C5CE7', '#D97706', '#64748B',
  ];
  static const _fuelEmojis = ['⛽', '🔥', '✨', '🛢️', '🔵', '🟣', '🔴', '🟢', '🟡', '⚫'];

  late final TextEditingController _nameKu, _nameAr, _nameEn;
  late final TextEditingController _emoji, _symbol, _per;
  late final TextEditingController _unitKu, _unitAr, _unitEn;
  late String _color;
  late String _group;

  bool get _isFuel => widget.kind == PriceKind.fuel;
  bool get _editing => widget.row != null;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    String v(String k) => '${r?[k] ?? ''}';
    _nameKu = TextEditingController(text: v('name_ku'));
    _nameAr = TextEditingController(text: v('name_ar'));
    _nameEn = TextEditingController(text: v('name_en'));
    _emoji = TextEditingController(text: v('emoji'));
    _symbol = TextEditingController(text: v('symbol'));
    _per = TextEditingController(text: r == null ? '1' : '${r['per'] ?? 1}');
    _unitKu = TextEditingController(
        text: r == null ? (_isFuel ? 'لیتر' : '') : v('unit_ku'));
    _unitAr = TextEditingController(
        text: r == null ? (_isFuel ? 'لتر' : '') : v('unit_ar'));
    _unitEn = TextEditingController(
        text: r == null ? (_isFuel ? 'L' : '') : v('unit_en'));
    _color = r == null ? _palette.first : v('color');
    _group = r == null ? (_isFuel ? 'fuel' : 'fiat') : v('grp');
  }

  @override
  void dispose() {
    for (final c in [
      _nameKu, _nameAr, _nameEn, _emoji, _symbol, _per,
      _unitKu, _unitAr, _unitEn,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _warn(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFFD9822B)),
    );
  }

  String? _opt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _save() {
    if (_nameKu.text.trim().isEmpty) {
      _warn(tr('ناوی کوردی پێویستە'));
      return;
    }
    final per = num.tryParse(_per.text.trim().replaceAll(',', '.')) ?? 0;
    if (!_isFuel && per <= 0) {
      _warn(tr('بڕی «بۆ چەند یەکە» دەبێت لە سفر گەورەتر بێت'));
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'name_ku': _nameKu.text.trim(),
      'name_ar': _opt(_nameAr),
      'name_en': _opt(_nameEn),
      'color': _color,
      'grp': _group,
      'emoji': _opt(_emoji),
      'symbol': _isFuel ? null : _opt(_symbol),
      'per': _isFuel ? 1 : per,
      'unit_ku': _opt(_unitKu),
      'unit_ar': _opt(_unitAr),
      'unit_en': _opt(_unitEn),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: Material(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(_editing ? 'دەستکاریکردنی جۆر' : 'جۆری نوێ'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: fg,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(tr('ناوی کوردی *'), _nameKu, isDark),
                        const SizedBox(height: 10),
                        _field(tr('ناوی عەرەبی'), _nameAr, isDark),
                        const SizedBox(height: 10),
                        _field(tr('ناوی ئینگلیزی'), _nameEn, isDark, ltr: true),
                        if (_editing) ...[
                          const SizedBox(height: 8),
                          Text(
                            trf('کلیل: {0} (ناگۆڕدرێت، چونکە نرخە پاشەکەوتکراوەکان پێوەی بەستراون)',
                                ['${widget.row!['key']}']),
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF8A90A0)),
                          ),
                        ],

                        _label(tr('بەش'), fg),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final g in _isFuel
                                ? const [('fuel', 'سووتەمەنی'), ('gas', 'گاز')]
                                : const [('fiat', 'دراو'), ('gold', 'زێڕ')])
                              ChoiceChip(
                                label: Text(tr(g.$2)),
                                selected: _group == g.$1,
                                selectedColor:
                                    AppColors.primary.withValues(alpha: 0.2),
                                onSelected: (_) =>
                                    setState(() => _group = g.$1),
                              ),
                          ],
                        ),

                        _label(
                            tr(_isFuel ? 'ئیمۆجی' : 'ئاڵا / ئیمۆجی'), fg),
                        _field(tr('ئیمۆجی'), _emoji, isDark),
                        if (_isFuel) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final e in _fuelEmojis)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _emoji.text = e),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _emoji.text == e
                                          ? AppColors.primary
                                              .withValues(alpha: 0.2)
                                          : (isDark
                                              ? const Color(0xFF0F0F14)
                                              : const Color(0xFFF4F6FA)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 19)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (!_isFuel) ...[
                          const SizedBox(height: 10),
                          _field(tr('هێما (بۆ نموونە \$ یان €)'), _symbol,
                              isDark),
                        ],

                        _label(tr('یەکەی نرخ'), fg),
                        Row(
                          children: [
                            Expanded(
                                child: _field(tr('کوردی'), _unitKu, isDark)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _field(tr('عەرەبی'), _unitAr, isDark)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _field(tr('ئینگلیزی'), _unitEn, isDark,
                                    ltr: true)),
                          ],
                        ),
                        if (!_isFuel) ...[
                          const SizedBox(height: 10),
                          _field(tr('نرخەکە بۆ چەند یەکەیە (بۆ نموونە ١٠٠)'),
                              _per, isDark,
                              keyboard: const TextInputType.numberWithOptions(
                                  decimal: true)),
                        ],

                        _label(tr('ڕەنگ'), fg),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final c in _palette)
                              GestureDetector(
                                onTap: () => setState(() => _color = c),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _AdminPriceTypesScreenState._hex(c),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _color.toUpperCase() ==
                                              c.toUpperCase()
                                          ? (isDark
                                              ? Colors.white
                                              : Colors.black)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: _color.toUpperCase() == c.toUpperCase()
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 18)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, MediaQuery.paddingOf(context).bottom + 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        tr(_editing ? 'نوێکردنەوە' : 'زیادکردن'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color fg) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: fg)),
      );

  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    bool ltr = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      textDirection: ltr ? TextDirection.ltr : null,
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        fontSize: 13.5,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade300,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
