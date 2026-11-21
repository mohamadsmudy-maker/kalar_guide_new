import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/tr.dart';
import '../models/opening_hours.dart';
import '../utils/place_display.dart';

String _time(String hm) => PlaceDisplay.digits(hm);

/// ڕێزی دۆخ: «کراوەیە • تا ٢١:٠٠» یان «داخراوە • دەکرێتەوە ئەمڕۆ ٠٨:٠٠».
String openStatusText(OpeningHours h, DateTime now) {
  if (h.is24h) return tr('٢٤ سەعات کراوەیە');
  final s = h.statusAt(now);
  final at = s.changeAt;
  String hm(DateTime d) => _time('${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
  if (s.open) {
    return at == null ? tr('کراوەیە') : trf('کراوەیە • تا {0}', [hm(at)]);
  }
  if (at == null) return tr('داخراوە');
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(at.year, at.month, at.day).difference(today).inDays;
  final when = diff == 0
      ? tr('ئەمڕۆ')
      : diff == 1
          ? tr('سبەینێ')
          : tr(OpeningHours.dayNames[OpeningHours.keyOfWeekday(at.weekday)]!);
  return trf('داخراوە • دەکرێتەوە {0} {1}', [when, hm(at)]);
}

/// نیشانەی بچووکی «کراوە / داخراو» بۆ کارتی شوێن
class OpenBadge extends StatelessWidget {
  final OpeningHours? hours;
  final DateTime? now;
  const OpenBadge({super.key, required this.hours, this.now});

  @override
  Widget build(BuildContext context) {
    final h = hours;
    if (h == null) return const SizedBox.shrink();
    final open = h.is24h || h.statusAt(now ?? DateTime.now()).open;
    final c = open ? const Color(0xFF0F9D7A) : const Color(0xFFDC3545);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(open ? tr('کراوە') : tr('داخراو'),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: c)),
        ],
      ),
    );
  }
}

/// بەشی کاتی کارکردن لە وردەکاری شوێن: دۆخی ئێستا + لیستی هەفتە
class OpeningHoursView extends StatelessWidget {
  final OpeningHours hours;
  final DateTime? now;
  const OpeningHoursView({super.key, required this.hours, this.now});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = now ?? DateTime.now();
    final open = hours.is24h || hours.statusAt(n).open;
    final c = open ? const Color(0xFF0F9D7A) : const Color(0xFFDC3545);
    final todayKey = OpeningHours.keyOfWeekday(n.weekday);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: Icon(Icons.schedule_rounded, color: c),
        title: Text(
          openStatusText(hours, n),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c),
        ),
        subtitle: Text(tr('کاتی کارکردن'),
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF8A90A0))),
        children: [
          if (hours.is24h)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(tr('هەموو ڕۆژێک، ٢٤ سەعات'),
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF4A5568))),
            )
          else
            for (final k in OpeningHours.dayKeys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(OpeningHours.dayNames[k]!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: k == todayKey ? FontWeight.w900 : FontWeight.w600,
                          color: k == todayKey
                              ? (isDark ? Colors.white : const Color(0xFF1A1A2E))
                              : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                    Text(
                      hours.days[k] == null
                          ? tr('داخراوە')
                          : '${_time(hours.days[k]!.open)} - ${_time(hours.days[k]!.close)}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: k == todayKey ? FontWeight.w900 : FontWeight.w600,
                        color: hours.days[k] == null
                            ? const Color(0xFFDC3545)
                            : (isDark ? Colors.white70 : const Color(0xFF4A5568)),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// دەستکاریکەری کاتی کارکردن (بۆ فۆڕمی زیادکردن/دەستکاری شوێن)
class OpeningHoursEditor extends StatefulWidget {
  final OpeningHours? initial;
  final ValueChanged<OpeningHours?> onChanged;
  const OpeningHoursEditor({super.key, this.initial, required this.onChanged});

  @override
  State<OpeningHoursEditor> createState() => _OpeningHoursEditorState();
}

class _OpeningHoursEditorState extends State<OpeningHoursEditor> {
  late bool _all24 = widget.initial?.is24h ?? false;
  late final Map<String, DayHours?> _days = {
    for (final k in OpeningHours.dayKeys) k: widget.initial?.days[k],
  };
  static const _def = DayHours('08:00', '21:00');

  void _emit() {
    final h = OpeningHours(is24h: _all24, days: Map.of(_days));
    widget.onChanged(h.isEmpty ? null : h);
  }

  Future<void> _pick(String k, bool open) async {
    final cur = _days[k] ?? _def;
    final s = open ? cur.open : cur.close;
    final p = s.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: w!,
      ),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => _days[k] = open ? DayHours(v, cur.close) : DayHours(cur.open, v));
    _emit();
  }

  void _copyFirst() {
    final first = _days.values.firstWhere((d) => d != null, orElse: () => null);
    if (first == null) return;
    setState(() {
      for (final k in OpeningHours.dayKeys) {
        if (k != 'fri') _days[k] = first; // هەینی وەک خۆی دەمێنێتەوە
      }
    });
    _emit();
  }

  /// 🪄 شێوە ئامادەکان: بە یەک کرتە هەموو ڕۆژەکان پڕ دەکاتەوە
  void _preset(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _all24 = id == '24h';
      for (final k in OpeningHours.dayKeys) {
        _days[k] = switch (id) {
          'daily' => const DayHours('08:00', '22:00'),
          'week' => k == 'fri' ? null : const DayHours('08:00', '21:00'),
          'office' => (k == 'fri' || k == 'sat') ? null : const DayHours('08:00', '14:00'),
          _ => null,
        };
      }
    });
    _emit();
  }

  int get _openDays => _all24 ? 7 : _days.values.where((d) => d != null).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final muted = isDark ? Colors.white54 : Colors.grey.shade600;
    const blue = Color(0xFF1E88E5);
    Widget chip(String id, IconData icon, String label) => ActionChip(
          key: ValueKey('hours-$id'),
          avatar: Icon(icon, size: 16, color: blue),
          label: Text(tr(label), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          backgroundColor: blue.withValues(alpha: 0.08),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
          onPressed: () => _preset(id),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr('کاتی کارکردن'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: fg)),
            ),
            Text(
              _all24
                  ? tr('٢٤ سەعات')
                  : _openDays == 0
                      ? tr('دیاری نەکراوە')
                      : trf('{0} ڕۆژ کراوەیە', [PlaceDisplay.digits(_openDays)]),
              key: const ValueKey('hours-summary'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 🪄 شێوە ئامادەکان
        Wrap(spacing: 6, runSpacing: 6, children: [
          chip('daily', Icons.wb_sunny_rounded, 'هەموو ڕۆژێک ٨–١٠'),
          chip('week', Icons.calendar_view_week_rounded, 'شەممە–پێنجشەممە'),
          chip('office', Icons.account_balance_rounded, 'دەوامی فەرمی ٨–٢'),
          chip('24h', Icons.all_inclusive_rounded, '٢٤ سەعات'),
          chip('clear', Icons.clear_rounded, 'پاککردنەوە'),
        ]),
        const SizedBox(height: 4),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(tr('٢٤ سەعات کراوەیە'), style: const TextStyle(fontWeight: FontWeight.w800)),
          value: _all24,
          onChanged: (v) {
            setState(() => _all24 = v);
            _emit();
          },
        ),
        if (!_all24) ...[
          for (final k in OpeningHours.dayKeys)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: _days[k] == null
                    ? (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F8FA))
                    : blue.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(tr(OpeningHours.dayNames[k]!),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
                  ),
                  Expanded(
                    child: _days[k] == null
                        ? Text(tr('داخراوە'), style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC3545)))
                        : Row(children: [
                            _timeBtn(_days[k]!.open, () => _pick(k, true)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('—'),
                            ),
                            _timeBtn(_days[k]!.close, () => _pick(k, false)),
                          ]),
                  ),
                  Switch(
                    key: ValueKey('day-$k'),
                    value: _days[k] != null,
                    onChanged: (v) {
                      setState(() => _days[k] = v ? _def : null);
                      _emit();
                    },
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _copyFirst,
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: Text(tr('هەموو ڕۆژەکان وەک یەکەم')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _timeBtn(String hm, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(PlaceDisplay.digits(hm), textDirection: TextDirection.ltr),
      );
}
