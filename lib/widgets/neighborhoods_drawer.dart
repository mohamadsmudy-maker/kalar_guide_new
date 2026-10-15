import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../models/neighborhood.dart';

class NeighborhoodsDrawer extends StatelessWidget {
  final List<Neighborhood> neighborhoods;
  final Function(Neighborhood) onSelected;
  final Neighborhood? current;

  const NeighborhoodsDrawer({
    super.key,
    required this.neighborhoods,
    required this.onSelected,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Drawer(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ───
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.map_rounded,
                        color: Colors.white, size: 36),
                    const SizedBox(height: 12),
                    const Text(
                      'ڕێبەری کەلار',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${neighborhoods.length} گەڕەک',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── لیست ───
              Expanded(
                child: neighborhoods.isEmpty
                    ? Center(
                  child: Text(
                    'هیچ گەڕەکێک نییە',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: neighborhoods.length,
                  itemBuilder: (_, i) {
                    final n = neighborhoods[i];
                    final selected = current?.id == n.id;

                    Color color;
                    try {
                      String hex = n.color.replaceAll('#', '');
                      if (hex.length == 6) hex = 'FF$hex';
                      color = Color(int.parse(hex, radix: 16));
                    } catch (_) {
                      color = const Color(0xFF1E88E5);
                    }

                    return ListTile(
                      selected: selected,
                      selectedTileColor:
                      color.withValues(alpha: 0.12),
                      leading: CircleAvatar(
                        backgroundColor: selected
                            ? color
                            : color.withValues(alpha: 0.2),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: selected ? Colors.white : color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        n.nameKu,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      subtitle: Text(
                        '${n.totalStores} شوێن',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(n);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}