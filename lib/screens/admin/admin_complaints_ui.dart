// lib/screens/admin/admin_complaints_ui.dart
// ڕووکاری _AdminComplaintsProScreenState — لە admin_complaints.dart جیاکراوەتەوە

part of 'admin_complaints.dart';

extension _AdminComplaintsProScreenStateUi on _AdminComplaintsProScreenState {
  Widget _buildSliverTabBar(bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade700,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: [
            _buildTab('هەموو', _allCount, Icons.apps_rounded),
            _buildTab('چاوەڕوان', _pendingCount, Icons.hourglass_top_rounded),
            _buildTab('پەسەند', _approvedCount, Icons.verified_rounded),
            _buildTab('تەواو', _completedCount, Icons.check_circle_rounded),
            _buildTab('ڕەتکراو', _rejectedCount, Icons.cancel_rounded),
          ],
        ),
        _bg(isDark),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📈 Stats
  // ═══════════════════════════════════════════════════════════
  Widget _buildSliverStats(bool isDark) {
    const green = Color(0xFF10B981);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _buildMiniStat(tr('کۆی'), _allCount, Icons.assignment_rounded,
                    const Color(0xFF6C5CE7), isDark),
                const SizedBox(width: 8),
                _buildMiniStat(tr('چاوەڕوان'), _pendingCount,
                    Icons.hourglass_top_rounded, const Color(0xFFFF9800), isDark),
                const SizedBox(width: 8),
                _buildMiniStat(tr('دواکەوتوو'), _overdueCount,
                    Icons.warning_amber_rounded, const Color(0xFFE53935), isDark),
                const SizedBox(width: 8),
                _buildMiniStat(tr('تەواو'), _completedCount,
                    Icons.check_circle_rounded, const Color(0xFF3498DB), isDark),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  green.withValues(alpha: 0.15),
                  green.withValues(alpha: 0.05),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('ڕێژەی جێبەجێکردن'),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: green)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('${_ku(_completionRate.toStringAsFixed(1))}%',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: green)),
                          const Spacer(),
                          Text(trf('{0} لە {1}', [_ku(_completedCount), _ku(_allCount)]),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _completionRate / 100,
                            minHeight: 5,
                            color: green,
                            backgroundColor: green.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
      String label, int value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(tr(_ku(value)),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1)),
          const SizedBox(height: 2),
          Text(tr(label),
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏘️ Neighborhood filter
  // ═══════════════════════════════════════════════════════════
  Widget _nbChip({
    required bool isDark,
    required bool selected,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int count = 0,
    List<Color>? selectedGradient,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                colors: selectedGradient ??
                    [color, Color.lerp(color, Colors.white, 0.2)!])
                : null,
            color: selected ? null : _surface(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(tr(label),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87))),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tr(_ku(count)),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : color)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildSliverNeighborhoodFilter(bool isDark) {
    if (_neighborhoods.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _neighborhoods.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _nbChip(
                isDark: isDark,
                selected: _filterNeighborhood == null,
                color: const Color(0xFF6C5CE7),
                icon: Icons.location_city_rounded,
                label: tr('هەموو گەڕەکەکان'),
                selectedGradient: const [Color(0xFF6C5CE7), Color(0xFF9C27B0)],
                onTap: () {
                  _filterNeighborhood = null;
                  _refilter();
                },
              );
            }
            final name = _neighborhoods[index - 1];
            final selected = _filterNeighborhood == name;
            return _nbChip(
              isDark: isDark,
              selected: selected,
              color: _neighborhoodColor(name),
              icon: Icons.place_rounded,
              label: name,
              count: _nbCounts[name] ?? 0,
              onTap: () {
                _filterNeighborhood = selected ? null : name;
                _refilter();
              },
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 List
  // ═══════════════════════════════════════════════════════════
  Widget _buildList(String tabKey, bool isDark) {
    final list = _tabLists[tabKey]!;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchComplaints(showLoader: false),
      child: list.isEmpty
          ? _buildEmpty(isDark)
          : ListView.builder(
        key: PageStorageKey('complaints_$tabKey'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final c = list[i];
          final card = _buildCard(c, isDark);
          if (i >= 8) return card;
          return AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              final delay = (i * 0.07).clamp(0.0, 0.6);
              final p =
              ((_staggerController.value - delay) / 0.4).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, 30 * (1 - p)),
                child: Opacity(opacity: p, child: child),
              );
            },
            child: card,
          );
        },
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color, {double? maxWidth}) {
    final text = Text(tr(label),
        style:
        TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 3),
        maxWidth == null
            ? text
            : Flexible(
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: text)),
      ]),
    );
  }

  Widget _buildTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(tr(label),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(tr(label),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🫥 Empty / error / skeleton
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmpty(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        Center(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_outlined,
                  size: 70, color: isDark ? Colors.white24 : AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(tr('هیچ سکاڵایەک نەدۆزرایەوە'),
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(
                tr(_hasActiveFilters
                    ? 'لەم فلتەر و بەروارەدا هیچ ئەنجامێک نییە'
                    : 'هێشتا هیچ سکاڵایەک نەنێردراوە'),
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade600)),
            const SizedBox(height: 20),
            if (_hasActiveFilters)
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text(tr('سڕینەوەی فلتەرەکان')),
              ),
          ]),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: isDark ? Colors.white38 : Colors.grey),
            const SizedBox(height: 16),
            Text(tr('نەتوانرا سکاڵاکان بار بکرێن'),
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(tr('ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵبدەرەوە'),
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchComplaints,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('دووبارە هەوڵبدەرەوە')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, __) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, i) => Opacity(
            opacity: 0.5 + (_pulseAnimation.value - 0.95) * 4,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 150,
              decoration: BoxDecoration(
                color: _surface(isDark),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎛 FABs + sheets
  // ═══════════════════════════════════════════════════════════
  Widget _buildFilterFab() {
    return FloatingActionButton.extended(
      onPressed: _showFilterSheet,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.tune_rounded),
      label:
      Text(tr('فلتەر'), style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildBulkActionsFab() {
    return FloatingActionButton.extended(
      onPressed: _showBulkActions,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.auto_fix_high_rounded),
      label: Text(trf('کار ({0})', [_ku(_selectedIds.length)]),
          style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}
