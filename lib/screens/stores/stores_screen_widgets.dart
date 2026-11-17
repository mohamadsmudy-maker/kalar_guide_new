// lib/screens/stores/stores_screen_widgets.dart
// بەشێک لە ڕووکاری _StoresScreenState — لە stores_screen.dart جیاکراوەتەوە

part of 'stores_screen.dart';

extension _StoresScreenStateWidgets on _StoresScreenState {
  Widget _buildFilterButton(bool isDark) {
    final n = (_selectedType != 'هەموو' ? 1 : 0) +
        (_selectedCategory != 'هەموو' ? 1 : 0);
    return Tooltip(
      message: tr('فلتەرکردن و ڕیزکردن'),
      child: GestureDetector(
        onTap: _showFilterSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: n > 0
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded,
                  size: 22, color: n > 0 ? Colors.white : AppColors.primary),
            ),
            if (n > 0)
              PositionedDirectional(
                top: -4,
                end: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2557A),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDark ? const Color(0xFF0F0F14) : Colors.white,
                        width: 2),
                  ),
                  child: Text('$n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required int? count,
    required bool selected,
    required bool dim,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 92,
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            color: selected
                ? color
                : (isDark ? const Color(0xFF1A1A22) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? color.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.22) : null,
                  gradient: selected
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(color, Colors.white, 0.2)!,
                            Color.lerp(color, Colors.black, 0.08)!
                          ],
                        ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AutoTranslate(
                  text: tr(label),
                  lang: AppLang.code,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
              ),
              if (count != null)
                Text(
                  PlaceDisplay.digits(count),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Stores List (وەک خۆی)
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoresList(bool isDark, String lang) {
    if (_loadingStores) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _buildSkeletonCard(isDark),
            childCount: 5,
          ),
        ),
      );
    }

    if (_filteredStores.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(isDark, lang));
    }

    final displayList = _filteredStores.take(_displayCount).toList();
    final hasMore = _displayCount < _filteredStores.length;

    if (_viewMode == 'grid') {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _buildGridCard(displayList[i], isDark, i),
            childCount: displayList.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == displayList.length) {
              if (!hasMore) return const SizedBox.shrink();
              return _buildLoadMoreButton(isDark);
            }

            final card = StoreCard(
              store: displayList[i],
              distance: _calculateDistance(
                double.tryParse(displayList[i]['latitude']?.toString() ?? ''),
                double.tryParse(displayList[i]['longitude']?.toString() ?? ''),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                StoreDetailsDialog.show(context, displayList[i]);
              },
            );

            if (i >= 8) return card;

            return AnimatedBuilder(
              animation: _entryAnimation,
              builder: (context, child) {
                final delay = (i * 0.06).clamp(0.0, 0.5);
                final progress =
                    ((_entryAnimation.value - delay) / 0.4).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - progress)),
                  child: Opacity(opacity: progress, child: child),
                );
              },
              child: card,
            );
          },
          childCount: displayList.length + (hasMore ? 1 : 0),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Grid Card (بۆ شێوازی گرید)
  // ═══════════════════════════════════════════════════════════
  Widget _buildGridCard(Map<String, dynamic> store, bool isDark, int index) {
    final name = store['name']?.toString() ?? 'شوێن';
    final image = store['image']?.toString() ?? '';
    final isGov = (store['type']?.toString() ?? '') == 'حکومی';

    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    final distance = _calculateDistance(lat, lng);

    final accentColor =
        isGov ? const Color(0xFF0F9D7A) : const Color(0xFFC2557A);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        StoreDetailsDialog.show(context, store);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: accentColor.withValues(alpha: 0.15), width: 1.5),
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
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: image.isNotEmpty
                        ? Image.network(image,
                            width: double.infinity, fit: BoxFit.cover)
                        : Container(
                            color: accentColor.withValues(alpha: 0.1),
                            child: Icon(Icons.storefront_rounded,
                                color: accentColor, size: 40),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr(name),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (distance < 99999.0)
                      Row(
                        children: [
                          const Icon(Icons.near_me_rounded,
                              size: 10, color: Color(0xFF0F9D7A)),
                          const SizedBox(width: 3),
                          Text(
                            trf('{0} کم', [
                              PlaceDisplay.digits(distance.toStringAsFixed(1))
                            ]),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0F9D7A),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💀 Skeleton Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildSkeletonCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 150,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📭 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark, String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.02)
                        ],
                      ),
                    ),
                    child: const Icon(Icons.location_off_rounded,
                        size: 60, color: AppColors.primary),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            AutoTranslate(
              text: _loadError != null
                  ? tr('بارکردن سەرکەوتوو نەبوو')
                  : _allStores.isEmpty
                      ? tr('هیچ شوێنێک نییە')
                      : tr('هیچ شوێنێک نەدۆزرایەوە'),
              lang: lang,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            AutoTranslate(
              text: _loadError != null
                  ? tr('پەیوەندی ئینتەرنێت بپشکنە و دووبارە هەوڵ بدەرەوە')
                  : _allStores.isEmpty
                      ? tr('داتابەیسەکە بەتاڵە — تکایە داتا زیاد بکە')
                      : tr('گەڕانەکەت هیچ ئەنجامێکی نەبوو'),
              lang: lang,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              maxLines: 2,
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SelectableText(
                  _loadError!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchStores(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr('دووبارە هەوڵ بدە'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap,
      {IconData? icon, int? count}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF334155));
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: AutoTranslate(
                text: tr(label),
                lang: AppLang.code,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                PlaceDisplay.digits(count),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: fg.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
