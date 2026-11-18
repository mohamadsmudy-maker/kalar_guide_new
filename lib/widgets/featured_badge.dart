// lib/widgets/featured_badge.dart
import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// ⭐ نیشانەی «پێشنیارکراو» بۆ شوێنی sponsored
class FeaturedBadge extends StatelessWidget {
  const FeaturedBadge({super.key, this.compact = false});

  final bool compact;

  static const gold = Color(0xFFE0A100);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('featured-badge'),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF5C542), gold]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: compact ? 11 : 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            tr('پێشنیارکراو'),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
