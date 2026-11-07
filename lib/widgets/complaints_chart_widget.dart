import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/tr.dart';

/// 📊 چارت بۆ نیشاندانی دۆخی سکاڵاکان — ULTRA PRO MAX V2
class ComplaintsChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> complaints;
  final bool isDark;

  const ComplaintsChartWidget({
    super.key,
    required this.complaints,
    required this.isDark,
  });

  @override
  State<ComplaintsChartWidget> createState() => _ComplaintsChartWidgetState();
}

class _ComplaintsChartWidgetState extends State<ComplaintsChartWidget> {
  /// Fixed display order (a Map used to give a random order)
  static const List<String> _order = [
    'pending',
    'approved',
    'completed',
    'rejected',
    'other',
  ];

  static const Map<String, String> _labels = {
    'pending': 'چاوەڕوان',
    // approved + in_progress share a colour in the admin panel, so they are
    // one slice here instead of two identical-looking ones
    'approved': 'پەسەندکراو / لە ئارادایە',
    'completed': 'جێبەجێکرا',
    'rejected': 'ڕەتکراو',
    'other': 'تر',
  };

  static const Map<String, Color> _colors = {
    'pending': Color(0xFFFF9800),
    'approved': Color(0xFF2ECC71),
    'completed': Color(0xFF3498DB),
    'rejected': Color(0xFFE74C3C),
    'other': Color(0xFF9E9E9E),
  };

  int _touched = -1;

  String _ku(Object n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  String _bucket(String? status) {
    switch (status) {
      case 'pending':
        return 'pending';
      case 'approved':
      case 'in_progress':
        return 'approved';
      case 'completed':
        return 'completed';
      case 'rejected':
        return 'rejected';
      default:
        return 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.complaints.isEmpty) return const SizedBox.shrink();

    final isDark = widget.isDark;
    final total = widget.complaints.length;

    final counts = <String, int>{};
    for (final c in widget.complaints) {
      final b = _bucket(c['status']?.toString() ?? 'pending');
      counts[b] = (counts[b] ?? 0) + 1;
    }

    final entries = [
      for (final key in _order)
        if ((counts[key] ?? 0) > 0) MapEntry(key, counts[key]!),
    ];

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white54 : Colors.grey;

    final summary = entries
        .map((e) => '${_labels[e.key]}: ${_ku(e.value)}')
        .join('، ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFFE91E63),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                tr('ئاماری سکاڵاکان'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                trf('کۆی {0}', [_ku(total)]),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🍩 Donut — tap a slice to highlight it
          Semantics(
            label: trf('چارتی سکاڵاکان. {0}', [summary]),
            child: SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final idx = (!event.isInterestedForInteractions ||
                              response?.touchedSection == null)
                              ? -1
                              : response!.touchedSection!.touchedSectionIndex;
                          if (idx != _touched) {
                            setState(() => _touched = idx);
                            if (idx >= 0) HapticFeedback.selectionClick();
                          }
                        },
                      ),
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          _section(entries[i], total, i == _touched),
                      ],
                    ),
                  ),
                  // Centre: total, or the touched slice's count
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr(_ku(_touched >= 0 && _touched < entries.length
                              ? entries[_touched].value
                              : total)),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _touched >= 0 && _touched < entries.length
                                ? _colors[entries[_touched].key]
                                : textColor,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(_touched >= 0 && _touched < entries.length
                              ? (_labels[entries[_touched].key] ?? '')
                              : 'سکاڵا'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 📋 Legend (with percentages)
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (var i = 0; i < entries.length; i++)
                _legendItem(entries[i], total, i == _touched, isDark),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(
      MapEntry<String, int> entry, int total, bool touched) {
    final percent = entry.value / total * 100;
    return PieChartSectionData(
      value: entry.value.toDouble(),
      color: _colors[entry.key] ?? Colors.grey,
      radius: touched ? 62 : 55,
      // tiny slices get no title — it would be unreadable and overlap
      showTitle: percent >= 6,
      title: trf('{0}٪', [_ku(percent.round())]),
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _legendItem(
      MapEntry<String, int> entry, int total, bool active, bool isDark) {
    final color = _colors[entry.key] ?? Colors.grey;
    final percent = entry.value / total * 100;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          trf('{0} ({1} • {2}٪)', [_labels[entry.key], _ku(entry.value), _ku(percent.round())]),
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.bold,
            color: active
                ? color
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }
}