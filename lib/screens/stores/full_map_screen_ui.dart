// lib/screens/stores/full_map_screen_ui.dart
// ڕووکاری _FullMapScreenState — لە full_map_screen.dart جیاکراوەتەوە

part of 'full_map_screen.dart';

extension _FullMapScreenStateUi on _FullMapScreenState {
  Widget _buildErrorBanner(bool isDark, double topPad) {
    return Positioned(
      top: topPad + 122,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _floatDecoration(isDark),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFD9822B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('نەتوانرا شوێنەکان بار بکرێن'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _fetchStores,
              child: Text(tr('دووبارە'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendPanel(bool isDark, double bottomInset) {
    final textColor = isDark ? Colors.white70 : Colors.black87;

    Widget item(Color color, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(tr(label),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
        ],
      ),
    );

    return Positioned(
      bottom: 96 + bottomInset,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _floatDecoration(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('ڕەنگی پینەکان'),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            item(const Color(0xFF0F9D7A), 'حکومی'),
            item(const Color(0xFF1E88E5), 'ناحکومی'),
            item(const Color(0xFFD9822B), 'خواردن'),
            item(const Color(0xFFDC3545), 'تەندروستی'),
            item(const Color(0xFF4F5BD5), 'پەروەردە'),
            item(const Color(0xFFD9822B), 'بازاڕ و دوکان'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: _floatDecoration(isDark, radius: 14),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    final total = _filteredPoints.length;
    final mapped = _mappableCount;
    final noLocation = total - mapped;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _filteredPoints.isEmpty ? null : () => _showStoreListSheet(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: _floatDecoration(isDark, radius: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF4F5BD5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('شوێنەکانی نەخشە'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          trf('{0} شوێن', [_ku(total)]),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color:
                            isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                        ),
                        if (mapped > 0)
                          _miniBadge(trf('{0} لەسەر نەخشە', [_ku(mapped)]),
                              Icons.location_on_rounded, const Color(0xFF0F9D7A)),
                        if (noLocation > 0)
                          _miniBadge(trf('{0} بێ لۆکەیشن', [_ku(noLocation)]),
                              Icons.location_off_rounded, const Color(0xFFD9822B)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.list_rounded,
                    color: AppColors.primary, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(tr(text),
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
