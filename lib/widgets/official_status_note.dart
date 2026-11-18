// lib/widgets/official_status_note.dart
import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../l10n/tr.dart';
import '../services/app_control.dart';

/// ⚖️ «ئەپی فەرمی نییە» یان «ئەپی فەرمیی …» — ئەدمین لە ناوەندی کۆنترۆڵ
/// دەیگۆڕێت، بێ وەشانی نوێی ئەپ.
class OfficialStatusNote extends StatelessWidget {
  const OfficialStatusNote({super.key, this.state});

  /// بۆ تاقیکردنەوە؛ ئەگینا AppControl.state
  final AppControlState? state;

  static String textFor(AppControlState s) => s.official
      ? trf('ئەمە ئەپی فەرمیی {0} ـە.', [tr(s.officialOrg)])
      : tr('ئەم ئەپە ئەپێکی سەربەخۆیە و ئەپی فەرمیی حکومەت یان شارەوانیی کەلار نییە. هەواڵ و زانیارییەکان لە سەرچاوە گشتییەکان و خاوەن شوێنەکانەوە کۆکراونەتەوە.');

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s != null) return _box(context, s);
    return ValueListenableBuilder<AppControlState>(
      valueListenable: AppControl.state,
      builder: (c, v, _) => _box(c, v),
    );
  }

  Widget _box(BuildContext context, AppControlState s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = s.official
        ? AppColors.green
        : (isDark ? Colors.white54 : AppColors.textSecondary);
    return Container(
      key: const ValueKey('official-status'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (s.official ? AppColors.green : (isDark ? Colors.white : AppColors.primary))
            .withValues(alpha: s.official ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.official ? Icons.verified_rounded : Icons.info_outline_rounded,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textFor(s),
              style: TextStyle(
                fontSize: s.official ? 13 : 11.5,
                height: 1.6,
                fontWeight: s.official ? FontWeight.w800 : FontWeight.w400,
                color: s.official ? color : (isDark ? Colors.white60 : AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
