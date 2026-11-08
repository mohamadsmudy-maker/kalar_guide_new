// lib/screens/favorites/favorites_screen_ui.dart
// ڕووکاری _FavoritesScreenState — لە favorites_screen.dart جیاکراوەتەوە

part of 'favorites_screen.dart';

extension _FavoritesScreenStateUi on _FavoritesScreenState {
  Widget _buildTabBar(bool isDark) {
    Widget tab(IconData icon, String label, int count) => Tab(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(tr(label)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tr(_ku(count)),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _card(isDark),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            gradient: const LinearGradient(colors: [_kPink, _kPurple]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kPink.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade700,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            tab(Icons.place_rounded, 'شوێنەکان', _items[_Kind.stores]!.length),
            tab(Icons.article_rounded, 'هەواڵەکان', _items[_Kind.news]!.length),
          ],
        ),
      ),
    );
  }

  Widget _scrollableCenter(_Kind kind, Widget child) {
    return RefreshIndicator(
      color: kind.color,
      onRefresh: () => _load(kind, silent: true),
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _dismissBg(Alignment align) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    alignment: align,
    decoration: BoxDecoration(
      color: Colors.red.shade400,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.heart_broken_rounded, color: Colors.white, size: 26),
        const SizedBox(height: 2),
        Text(tr('لابردن'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900)),
      ],
    ),
  );

  Widget _entry(int index, Widget child) {
    if (index >= 6) return child;
    return AnimatedBuilder(
      animation: _entryAnimation,
      builder: (context, c) {
        final delay = (index * 0.08).clamp(0.0, 0.5);
        final p = ((_entryAnimation.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - p)),
          child: Opacity(opacity: p, child: c),
        );
      },
      child: child,
    );
  }

  Widget _buildBatchBar({
    required bool isDark,
    required Color color,
    required int selectedCount,
    required int totalCount,
    required VoidCallback onSelectAll,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(trf('{0} / {1} هەڵبژێردراو', [_ku(selectedCount), _ku(totalCount)]),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelectAll();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                tr(selectedCount == totalCount && totalCount > 0
                    ? 'هەڵوەشاندنەوە'
                    : 'هەموو'),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ),
          if (selectedCount > 0) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _deleting ? null : onDelete,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(8)),
                child: _deleting
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(tr('سڕینەوە'),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🃏 Cards
  // ═══════════════════════════════════════════════════════════
  Widget _checkbox(Color color, bool selected) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: selected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color, width: 2),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
        : null,
  );

  Widget _unfavButton(_Kind kind, Map<String, dynamic> item) => InkWell(
    onTap: () => _removeOne(kind, item),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.favorite_rounded, color: kind.color, size: 18),
    ),
  );

  Widget _buildStoreCard(Map<String, dynamic> item, bool isDark, bool isSel) {
    final store = Map<String, dynamic>.from(item['data'] as Map);
    final id = item['fav_id'].toString();
    final ago = _ago(item['created_at']);

    return GestureDetector(
      onTap: () {
        if (_batchMode) {
          _toggleSelect(_Kind.stores, id);
        } else {
          StoreDetailsDialog.show(context, store);
        }
      },
      onLongPress: () {
        if (_batchMode) {
          _toggleSelect(_Kind.stores, id);
        } else {
          _enterBatchWith(_Kind.stores, id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _cardDecoration(_kPink, isDark, isSel),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (_batchMode) ...[
                _checkbox(_kPink, isSel),
                const SizedBox(width: 12),
              ],
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _kPink.withValues(alpha: 0.25), width: 2),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: OptimizedNetworkImage(
                    imageUrl: (store['image'] ?? '').toString(),
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr((store['name'] ?? '').toString()),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: _title(isDark)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: _kPink),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            tr((store['address'] ?? 'کەلار').toString()),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _sub(isDark)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (store['category'] != null)
                          ProBadge(
                            label: store['category'].toString(),
                            icon: Icons.category_rounded,
                            color: _kPink,
                          ),
                        if (store['category'] != null && ago.isNotEmpty)
                          const SizedBox(width: 8),
                        if (ago.isNotEmpty)
                          Flexible(
                            child: Text(tr(ago),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_batchMode) _unfavButton(_Kind.stores, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> fav, bool isDark, bool isSel) {
    final news = Map<String, dynamic>.from(fav['data'] as Map);
    final id = fav['fav_id'].toString();
    final img = _extractFirstImage(news['images'] ?? news['img']);
    final ago = _ago(fav['created_at']);

    return GestureDetector(
      onTap: () {
        if (_batchMode) {
          _toggleSelect(_Kind.news, id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsDetailsScreen(newsItem: news)),
          ).then((_) {
            if (mounted) _load(_Kind.news, silent: true);
          });
        }
      },
      onLongPress: () {
        if (_batchMode) {
          _toggleSelect(_Kind.news, id);
        } else {
          _enterBatchWith(_Kind.news, id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _cardDecoration(_kPurple, isDark, isSel),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (img.isNotEmpty)
              Stack(
                children: [
                  OptimizedNetworkImage(
                    imageUrl: img,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  if (_batchMode)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _checkbox(_kPurple, isSel),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_rounded,
                                color: Colors.pink, size: 12),
                            const SizedBox(width: 4),
                            Text(tr('دڵخواز'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_batchMode && img.isEmpty) ...[
                    _checkbox(_kPurple, isSel),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr((news['title'] ?? '').toString()),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: _title(isDark),
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr((news['description'] ?? '').toString()),
                          style: TextStyle(
                              fontSize: 12, height: 1.5, color: _sub(isDark)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ago.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.bookmark_added_rounded,
                                  size: 12,
                                  color: _kPurple.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(tr(ago),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_batchMode) ...[
                    const SizedBox(width: 8),
                    _unfavButton(_Kind.news, fav),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.02)
                    ],
                  ),
                ),
                child: Icon(icon, size: 60, color: color),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr(title),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _title(isDark)),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(tr(subtitle),
              style: TextStyle(fontSize: 12, height: 1.6, color: _sub(isDark)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
