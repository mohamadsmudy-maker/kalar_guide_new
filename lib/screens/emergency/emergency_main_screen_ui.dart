// lib/screens/emergency/emergency_main_screen_ui.dart
// ڕووکاری _EmergencyScreenState — لە emergency_main_screen.dart جیاکراوەتەوە

part of 'emergency_main_screen.dart';

extension _EmergencyScreenStateUi on _EmergencyScreenState {
  // ───────────────────────────────────────────────────────
  // AppBar
  // ───────────────────────────────────────────────────────
  Widget _buildAppBar(
      bool isDark,
      AsyncValue<List<EmergencyService>> servicesAsync,
      EmergencyFilter filter,
      ) {
    final count = servicesAsync.maybeWhen(
      data: (l) => l.length,
      orElse: () => 0,
    );

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFFDC2626),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
          tooltip: 'نوێکردنەوە',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFFF7043), Color(0xFFE53935)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              // …decorative circles unchanged…
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) => Transform.scale(
                          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.6,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.emergency_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ژمارەکانی فریاکەوتن',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _pill(
                                  icon: Icons.phone_rounded,
                                  label: '$count ژمارە',
                                ),
                                const SizedBox(width: 8),
                                _pill(
                                  icon: Icons.access_time_filled_rounded,
                                  label: '٢٤/٧',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Filters
  // ───────────────────────────────────────────────────────
  Widget _buildFilters(bool isDark, EmergencyFilter filter) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: EmergencyCategories.all.length,
        itemBuilder: (context, i) {
          final cat = EmergencyCategories.all[i];
          final selected = filter.category == cat.key;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(emergencyFilterProvider.notifier).setCategory(cat.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                    colors: [
                      cat.color,
                      cat.color.withValues(alpha: 0.7),
                    ],
                  )
                      : null,
                  color: selected
                      ? null
                      : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200),
                  ),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: cat.color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.iconData,
                      size: 14,
                      color: selected
                          ? Colors.white
                          : cat.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.getName('ku'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Sort bar
  // ───────────────────────────────────────────────────────
  Widget _buildSortBar(bool isDark, EmergencyFilter filter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 16,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          const SizedBox(width: 8),
          ...EmergencySort.values.map((sort) {
            final selected = filter.sort == sort;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(emergencyFilterProvider.notifier).setSort(sort);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFDC2626)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sort.icon,
                        size: 12,
                        color: selected
                            ? const Color(0xFFDC2626)
                            : (isDark ? Colors.white54 : Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sort.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? const Color(0xFFDC2626)
                              : (isDark ? Colors.white54 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────
  // Stats card
  // ───────────────────────────────────────────────────────
  Widget _buildStatsCard(
      bool isDark,
      EmergencyFilter filter,
      int count,
      Position? pos,
      ) {
    final hasPosition = pos != null;
    final sortIsDistance = filter.sort == EmergencySort.distance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFDC2626).withValues(alpha: 0.15),
              const Color(0xFFFF7043).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count ژمارە بەردەستە',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (hasPosition && sortIsDistance)
                    Text(
                      'ڕیزکراوە بەپێی دووری لە شوێنەکەت',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (hasPosition)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded,
                        color: Colors.green, size: 11),
                    SizedBox(width: 3),
                    Text(
                      'نزیک',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
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

  // ───────────────────────────────────────────────────────
  // Body
  // ───────────────────────────────────────────────────────
  Widget _buildBody(
      bool isDark,
      AsyncValue<List<EmergencyService>> servicesAsync,
      List<EmergencyRow> rows,
      EmergencyFilter filter,
      ) {
    // 1️⃣ Loading (initial)
    if (servicesAsync.isLoading && !servicesAsync.hasValue) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFDC2626)),
        ),
      );
    }

    // 2️⃣ Error
    if (servicesAsync.hasError && !servicesAsync.hasValue) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildError(isDark, servicesAsync.error!),
      );
    }

    // 3️⃣ Empty
    if (rows.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmpty(isDark, filter),
      );
    }

    // 4️⃣ List
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        40 + MediaQuery.of(context).padding.bottom,
      ),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];
          final card = _EmergencyCard(
            key: ValueKey('svc-${row.service.id ?? row.service.phone}-$i'),
            row: row,
            isDark: isDark,
            pulse: _pulseController,
            pulseValue: _pulseAnimation,
            entry: _entryAnimation,
            index: i,
            onCall: () => _call(row.service.phone),
            onDirections: () => _openDirections(row.service),
            onShare: () => _share(row.service),
            onCopied: (msg) => _copyAndToast(msg, msg),
          );
          return RepaintBoundary(child: card);
        },
      ),
    );
  }

  Widget _buildError(bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 60, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text(
              'هەڵە لە بارکردنی داتا',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دووبارە هەوڵ بدە'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark, EmergencyFilter filter) {
    final searching = filter.search.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFDC2626).withValues(alpha: 0.2),
                        const Color(0xFFDC2626).withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.emergency_outlined,
                    size: 60,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              searching ? 'هیچ ئەنجامێک نەدۆزرایەوە' : 'هیچ ژمارەیەک نییە',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'گەڕانەکەت هیچ ئەنجامێکی نەبوو'
                  : 'تکایە داتا لە داتابەیس زیاد بکە',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
