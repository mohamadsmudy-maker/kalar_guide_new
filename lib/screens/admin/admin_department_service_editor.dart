import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/tr.dart';

/// لیستی دەق لە خانەی داتابەیس (List یان دەقی `{a,b}` یان چەند دێڕ)
List<String> serviceListOf(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    final s = raw.trim().replaceAll(RegExp(r'^[\{\[]|[\}\]]$'), '');
    return s
        .split(RegExp(r'[\n,]'))
        .map((e) => e.replaceAll('"', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [];
}

/// پێداویستییەکانی مامەڵە — `requirements`، ئەگەر بەتاڵ بوو `documents` ی کۆن
List<String> serviceRequirementsOf(Map<String, dynamic>? service) {
  final r = serviceListOf(service?['requirements']);
  return r.isNotEmpty ? r : serviceListOf(service?['documents']);
}

/// 📝 فۆرمی زیادکردن / دەستکاریکردنی مامەڵەی فەرمانگە:
/// ناو، پێداویستییەکان (کارتی نیشتمانی، ...)، تێچوو، ماوە و تێبینی.
/// ئەگەر پاشەکەوت کرا `true` دەگەڕێنێتەوە.
class ServiceEditorSheet extends StatefulWidget {
  final dynamic departmentId;
  final Map<String, dynamic>? service;
  final Color color;

  const ServiceEditorSheet({
    super.key,
    required this.departmentId,
    this.service,
    this.color = const Color(0xFF0F9D7A),
  });

  /// پێداویستییە باوەکان — بە یەک کلیک زیاد دەکرێن
  static const List<String> commonRequirements = [
    'کارتی نیشتمانی',
    'کارتی زانیاری',
    'ناسنامەی باری شارستانی',
    'ڕەگەزنامەی عێراقی',
    'پسووڵەی خۆراک',
    'وێنەی کەسی',
    'پشتگیری نیشتەجێبوون',
    'پشکنینی پزیشکی',
  ];

  @override
  State<ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends State<ServiceEditorSheet> {
  late final TextEditingController _titleKu;
  late final TextEditingController _titleAr;
  late final TextEditingController _titleEn;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _notes;
  final _reqInput = TextEditingController();
  final _feeName = TextEditingController();
  final _feeAmount = TextEditingController();

  late List<String> _requirements;
  late List<String> _fees;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _titleKu = TextEditingController(text: '${s?['title_ku'] ?? ''}');
    _titleAr = TextEditingController(text: '${s?['title_ar'] ?? ''}');
    _titleEn = TextEditingController(text: '${s?['title_en'] ?? ''}');
    _description = TextEditingController(text: '${s?['description'] ?? ''}');
    _duration = TextEditingController(text: '${s?['duration'] ?? ''}');
    _notes = TextEditingController(text: '${s?['notes'] ?? ''}');
    _requirements = serviceRequirementsOf(s);
    _fees = serviceListOf(s?['fees']);
  }

  @override
  void dispose() {
    for (final c in [
      _titleKu,
      _titleAr,
      _titleEn,
      _description,
      _duration,
      _notes,
      _reqInput,
      _feeName,
      _feeAmount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRequirement([String? value]) {
    final v = (value ?? _reqInput.text).trim();
    if (v.isEmpty) return;
    setState(() {
      if (!_requirements.contains(v)) _requirements.add(v);
      if (value == null) _reqInput.clear();
    });
  }

  void _addFee() {
    final name = _feeName.text.trim();
    final amount = _feeAmount.text.trim();
    if (name.isEmpty && amount.isEmpty) return;
    final line = name.isEmpty
        ? amount
        : amount.isEmpty
            ? name
            : '$name: $amount';
    setState(() {
      _fees.add(line);
      _feeName.clear();
      _feeAmount.clear();
    });
  }

  String? _nullIfEmpty(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (_titleKu.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('ناوی مامەڵە پێویستە')),
          backgroundColor: const Color(0xFFD9822B),
        ),
      );
      return;
    }
    // ئەوەی لە خانەکاندا نووسراوە بەڵام «زیادکردن»ی لێ نەدراوە، ون نەبێت
    _addRequirement();
    _addFee();

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'department_id': widget.departmentId,
        'title_ku': _titleKu.text.trim(),
        'title_ar': _nullIfEmpty(_titleAr),
        'title_en': _nullIfEmpty(_titleEn),
        'description': _nullIfEmpty(_description),
        'duration': _nullIfEmpty(_duration),
        'notes': _nullIfEmpty(_notes),
        'requirements': _requirements,
        'fees': _fees,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final table = Supabase.instance.client.from('department_services');
      if (widget.service == null) {
        await table.insert(data);
      } else {
        await table.update(data).eq('id', widget.service!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.service != null;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final color = widget.color;
    final suggestions = ServiceEditorSheet.commonRequirements
        .where((e) => !_requirements.contains(e))
        .toList();

    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    Icon(Icons.description_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(isEditing
                            ? 'دەستکاریکردنی مامەڵە'
                            : 'زیادکردنی مامەڵە'),
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(tr('ناوی مامەڵە *'), _titleKu, isDark,
                          hint: tr('بۆ نموونە: دەرهێنانی مۆڵەتی شۆفێری')),
                      const SizedBox(height: 10),
                      _field(tr('وەسف'), _description, isDark, maxLines: 2),

                      // ═══ پێداویستییەکان ═══
                      _heading(Icons.fact_check_rounded,
                          tr('پێداویستییەکانی مامەڵە'), color, fg,
                          count: _requirements.length),
                      for (var i = 0; i < _requirements.length; i++)
                        _itemRow(
                          '${i + 1}',
                          _requirements[i],
                          isDark,
                          color,
                          () => setState(() => _requirements.removeAt(i)),
                        ),
                      _addRow(
                        isDark: isDark,
                        color: color,
                        onAdd: _addRequirement,
                        children: [
                          Expanded(
                            child: _field(
                              tr('پێداویستییەکی نوێ'),
                              _reqInput,
                              isDark,
                              onSubmitted: (_) => _addRequirement(),
                            ),
                          ),
                        ],
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in suggestions)
                              ActionChip(
                                label: Text(
                                  tr(s),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                avatar: Icon(Icons.add_rounded,
                                    size: 16, color: color),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _addRequirement(s),
                              ),
                          ],
                        ),
                      ],

                      // ═══ تێچوو ═══
                      _heading(Icons.payments_rounded, tr('تێچووی مامەڵە'),
                          color, fg,
                          count: _fees.length),
                      for (var i = 0; i < _fees.length; i++)
                        _itemRow(
                          '${i + 1}',
                          _fees[i],
                          isDark,
                          color,
                          () => setState(() => _fees.removeAt(i)),
                        ),
                      _addRow(
                        isDark: isDark,
                        color: color,
                        onAdd: _addFee,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _field(tr('جۆری تێچوو'), _feeName, isDark,
                                hint: tr('ڕەسم')),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: _field(tr('بڕ'), _feeAmount, isDark,
                                hint: tr('٢٥,٠٠٠ دینار'),
                                onSubmitted: (_) => _addFee()),
                          ),
                        ],
                      ),

                      // ═══ زانیاری زیاتر ═══
                      _heading(Icons.info_outline_rounded,
                          tr('زانیاری زیاتر'), color, fg),
                      _field(tr('ماوەی تەواوبوون'), _duration, isDark,
                          hint: tr('بۆ نموونە: ٣ ڕۆژ')),
                      const SizedBox(height: 10),
                      _field(tr('تێبینی'), _notes, isDark, maxLines: 2),
                      const SizedBox(height: 10),
                      _field(tr('ناوی عەرەبی'), _titleAr, isDark),
                      const SizedBox(height: 10),
                      _field(tr('ناوی ئینگلیزی'), _titleEn, isDark),
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
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      tr(isEditing ? 'نوێکردنەوە' : 'پاشەکەوتکردن'),
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
    );
  }

  Widget _heading(IconData icon, String title, Color color, Color fg,
      {int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: fg),
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(String index, String text, bool isDark, Color color,
      VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 2, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            index,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('لابردن'),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFFDC3545)),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _addRow({
    required bool isDark,
    required Color color,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return Row(
      children: [
        ...children,
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          height: 46,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onAdd,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    int maxLines = 1,
    String? hint,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
