// lib/widgets/live_badge.dart
import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// 🟢 نیشانەی «ڕاستەوخۆ» بۆ نرخەکان. تەنها کاتێک سەوزە کە نرخەکە لە
/// [freshFor] ـی ڕابردوودا نوێ کرابێتەوە؛ ئەگینا «نرخی کۆن» بە خۆڵەمێشی.
class LiveBadge extends StatelessWidget {
  const LiveBadge({
    super.key,
    required this.updated,
    this.flash = false,
    this.freshFor = const Duration(hours: 24),
    this.now,
  });

  final DateTime? updated;
  final bool flash;
  final Duration freshFor;

  /// بۆ تاقیکردنەوە
  final DateTime? now;

  static bool isFresh(DateTime? updated, {Duration freshFor = const Duration(hours: 24), DateTime? now}) {
    if (updated == null) return false;
    return (now ?? DateTime.now()).difference(updated.toLocal()) <= freshFor;
  }

  @override
  Widget build(BuildContext context) {
    final fresh = isFresh(updated, freshFor: freshFor, now: now);
    const green = Color(0xFF10B981);
    final dot = fresh ? (flash ? Colors.white : green) : Colors.white54;
    return AnimatedContainer(
      key: ValueKey(fresh ? 'live-fresh' : 'live-stale'),
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fresh && flash ? green : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(tr(fresh ? 'ڕاستەوخۆ' : 'نرخی کۆن'),
            style: TextStyle(
                color: fresh ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
