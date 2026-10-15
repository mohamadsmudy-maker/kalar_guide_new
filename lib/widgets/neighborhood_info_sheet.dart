import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';
import '../../screens/neighborhoods/neighborhood_details_screen.dart';

/// 🏘️ کارتی زانیاری گەڕەک لەسەر نەخشە
class NeighborhoodInfoSheet extends StatelessWidget {
  final Neighborhood neighborhood;
  final VoidCallback onClose;

  const NeighborhoodInfoSheet({
    super.key,
    required this.neighborhood,
    required this.onClose,
  });

  Color get _color => neighborhood.displayColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = neighborhood;
    final color = _color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Drag Handle ───
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Header ───
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_city_rounded,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  n.nameKu,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white12 : null),
          const SizedBox(height: 4),

          // ─── Stats ───
          _infoRow(
            icon: Icons.storefront_rounded,
            label: 'شوێن',
            value: '${n.totalStores}',
            color: color,
            isDark: isDark,
          ),
          if (n.population > 0)
            _infoRow(
              icon: Icons.people_rounded,
              label: 'دانیشتوو',
              value: '${n.population}',
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
          if (n.areaKm2 > 0)
            _infoRow(
              icon: Icons.square_foot_rounded,
              label: 'ڕووبەر',
              value: '${n.areaKm2.toStringAsFixed(3)} کم²',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            ),
          if (n.hasBoundary)
            _infoRow(
              icon: Icons.polyline_rounded,
              label: 'خاڵی سنوور',
              value: '${n.boundaryPoints.length}',
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),

          const SizedBox(height: 16),

          // ─── دوگمەی زانیاری زیاتر ───
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text(
                'زانیاری زیاتر',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NeighborhoodDetailsScreen(neighborhood: n),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}