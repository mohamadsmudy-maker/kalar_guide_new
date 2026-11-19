// lib/widgets/neighborhoods/waste_schedule_card.dart
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/waste_schedule_service.dart';

/// 🗑️ کاتی هاتنی ئۆتۆمبێلی خۆڵ بۆ گەڕەکێک + ئاگادارکردنەوەی شەوی پێشتر
class WasteScheduleCard extends StatefulWidget {
  const WasteScheduleCard({
    super.key,
    required this.neighborhoodId,
    required this.neighborhoodName,
    this.loader,
    this.subscription,
    this.onSubscribe,
    this.clock,
  });

  final int neighborhoodId;
  final String neighborhoodName;

  // بۆ تاقیکردنەوە
  final Future<WasteSchedule?> Function(int id)? loader;
  final Future<int?> Function()? subscription;
  final Future<void> Function(int? id)? onSubscribe;
  final DateTime Function()? clock;

  @override
  State<WasteScheduleCard> createState() => _WasteScheduleCardState();
}

class _WasteScheduleCardState extends State<WasteScheduleCard> {
  static const _green = Color(0xFF0F9D7A);
  WasteSchedule? _s;
  bool _loaded = false;
  bool _remind = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await (widget.loader ??
        WasteScheduleService.forNeighborhood)(widget.neighborhoodId);
    final sub = await (widget.subscription ??
        WasteScheduleService.subscribedNeighborhood)();
    if (!mounted) return;
    setState(() {
      _s = s;
      _remind = sub == widget.neighborhoodId;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    final id = on ? widget.neighborhoodId : null;
    await (widget.onSubscribe ??
        (v) => WasteScheduleService.subscribe(v,
            name: widget.neighborhoodName))(id);
    if (!mounted) return;
    setState(() {
      _remind = on;
      _busy = false;
    });
  }

  String _nextLabel(WasteSchedule s) {
    final now = (widget.clock ?? DateTime.now)();
    final next = s.nextCollection(now);
    if (next == null) return '';
    final today = DateTime(now.year, now.month, now.day);
    final diff = next.difference(today).inDays;
    if (diff == 0) return tr('ئەمڕۆ');
    if (diff == 1) return tr('سبەی');
    return tr(WasteSchedule.dayName(next.weekday));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (!_loaded || s == null || s.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : Colors.grey.shade700;

    return Container(
      key: const ValueKey('waste-schedule-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_shipping_rounded, color: _green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr('کاتی هاتنی ئۆتۆمبێلی خۆڵ'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trf('داهاتوو: {0}', [_nextLabel(s)]),
                key: const ValueKey('waste-next'),
                style: const TextStyle(
                    fontSize: 11.5, color: _green, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final d in WasteSchedule.weekOrder)
              if (s.weekdays.contains(d))
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _green.withValues(alpha: 0.10),
                  side: BorderSide.none,
                  label: Text(tr(WasteSchedule.dayName(d)),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
          ]),
          if (s.timeText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(trf('کات: {0}', [s.timeText]),
                style: TextStyle(fontSize: 12.5, color: muted)),
          ],
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(tr(s.note),
                style: TextStyle(fontSize: 12, height: 1.5, color: muted)),
          ],
          const Divider(height: 18),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const ValueKey('waste-remind'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: _green,
              title: Text(tr('ئاگادارم بکەرەوە شەوی پێشتر'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text(tr('کاتژمێر ٨ ی ئێوارە، شەوی پێش هاتنی ئۆتۆمبێل'),
                  style: TextStyle(fontSize: 11.5, color: muted)),
              value: _remind,
              onChanged: _busy ? null : _toggle,
            ),
          ),
        ],
      ),
    );
  }
}
