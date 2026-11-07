// lib/screens/admin/admin_dashboard_ui.dart
// ڕووکاری _AdminDashboardScreenState — لە admin_dashboard.dart جیاکراوەتەوە

part of 'admin_dashboard.dart';

extension _AdminDashboardScreenStateUi on _AdminDashboardScreenState {
  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isAdmin) {
    final hasError = _loadError != null;

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _kAppBarColor,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(''),
      actions: [
        IconButton(
          icon: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.refresh_rounded),
          onPressed: _loading
              ? null
              : () {
            HapticFeedback.selectionClick();
            if (!_reduceMotion) _entryController.forward(from: 0);
            _loadData();
          },
          tooltip: tr('نوێکردنەوە'),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A1B2E),
                Color(0xFF2D1B4E),
                Color(0xFF8B5CF6),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 180,
                      height: 180,
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
                  width: 120,
                  height: 120,
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
                        builder: (context, child) => Transform.scale(
                          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr(isAdmin ? 'پانێڵی ئەدمین' : 'پانێڵی بەڕێوەبردن'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FadeTransition(
                              opacity: _headerAnimation,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: hasError
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      tr(hasError
                                          ? (_lastUpdated == null
                                          ? 'کێشەی پەیوەندی'
                                          : trf('کێشەی پەیوەندی • دوایین نوێکردنەوە {0}', [_lastUpdatedText]))
                                          : (_lastUpdated == null
                                          ? 'سیستەم چالاکە'
                                          : trf('سیستەم چالاکە • {0}', [_lastUpdatedText]))),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⚠️ Banners
  // ═══════════════════════════════════════════════════════════
  Widget _buildErrorBanner(_Palette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(_loadError ?? ''),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : () => _loadData(),
              child: Text(
                tr('دووبارە'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🚨 Shows only when something needs the admin's attention
  Widget _buildAttentionBanner(_Palette p, bool isAdmin) {
    final showRequests =
        _pendingRequests > 0 && (isAdmin || !_kRestrictSensitiveToAdmin);
    if (_pendingComplaints <= 0 && !showRequests) {
      return const SizedBox.shrink();
    }

    Widget chip(String label, IconData icon, VoidCallback onTap) {
      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  tr(label),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _Entry(
      animation: _entryController,
      index: 2,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notification_important_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('پێویستی بە سەرنجە'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_pendingComplaints > 0)
                    chip(
                      trf('{0} سکاڵای چاوەڕوان', [_ku(_pendingComplaints)]),
                      Icons.hourglass_empty_rounded,
                          () => _push(const AdminComplaintsProScreen()),
                    ),
                  if (showRequests)
                    chip(
                      trf('{0} داوکاری ئەدمین', [_ku(_pendingRequests)]),
                      Icons.assignment_ind_rounded,
                          () => _push(const AdminVendorRequestsScreen()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🦸 Hero cards (live users + AI chat share one builder)
  // ═══════════════════════════════════════════════════════════
  Widget _heroCard({
    required int itemIndex,
    required List<Color> colors,
    required IconData icon,
    required String title,
    required Widget subtitle,
    required String semanticsLabel,
    required VoidCallback onTap,
    bool shimmer = false,
  }) {
    return _Entry(
      animation: _entryController,
      index: itemIndex,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
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
                            tr(title),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          subtitle,
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (shimmer && !_reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(
                                -1.0 + _shimmerController.value * 3,
                                -1.0,
                              ),
                              end: Alignment(
                                1.0 + _shimmerController.value * 3,
                                1.0,
                              ),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveUsersCard({required int itemIndex}) {
    return _heroCard(
      itemIndex: itemIndex,
      colors: const [Color(0xFF10B981), Color(0xFF059669)],
      icon: Icons.people_rounded,
      title: tr('بەکارهێنەرانی چالاک'),
      semanticsLabel:
      trf('بەکارهێنەرانی چالاک، {0} ئێستا لە خەتە', [_ku(_onlineUsers)]),
      onTap: () => _push(const AdminLiveUsersScreen()),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            trf('{0} ئێستا لە خەتە', [_ku(_onlineUsers)]),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Section header + Stats
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, _Palette p,
      {required int itemIndex}) {
    return _Entry(
      animation: _entryController,
      index: itemIndex,
      from: const Offset(20, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF6C5CE7)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tr(title),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(_Palette p, bool isAdmin) {
    final canOpenRequests = isAdmin || !_kRestrictSensitiveToAdmin;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // ✅ بەرزی کارتەکە زیادکرا بۆ ١١٨ بۆ ئەوەی کێشەی ئۆڤەرفلۆ نەبێت
        mainAxisExtent: 118.0 * scale,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          p: p,
          icon: Icons.storefront_rounded,
          label: tr('شوێنەکان'),
          value: _totalStores,
          color: const Color(0xFFF59E0B),
          itemIndex: 3,
          onTap: () => _push(const AdminStoresScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.business_rounded,
          label: tr('فەرمانگەکان'),
          value: _totalDepartments,
          color: const Color(0xFF10B981),
          itemIndex: 4,
          onTap: () => _push(const AdminDepartmentsScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.report_rounded,
          label: tr('کۆی سکاڵاکان'),
          value: _totalComplaints,
          color: const Color(0xFFE91E63),
          itemIndex: 5,
          onTap: () => _push(const AdminComplaintsProScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.hourglass_empty_rounded,
          label: tr('سکاڵای چاوەڕوان'),
          value: _pendingComplaints,
          color: const Color(0xFFEF4444),
          itemIndex: 6,
          isImportant: _pendingComplaints > 0,
          onTap: () => _push(const AdminComplaintsProScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.assignment_ind_rounded,
          label: tr('داوکاری ئەدمین'),
          value: _pendingRequests,
          color: const Color(0xFF8B5CF6),
          itemIndex: 7,
          isImportant: _pendingRequests > 0,
          onTap: canOpenRequests
              ? () => _push(const AdminVendorRequestsScreen())
              : null,
        ),
        _buildStatCard(
          p: p,
          icon: Icons.shopping_bag_rounded,
          label: tr('کاڵاکان'),
          value: _totalProducts,
          color: const Color(0xFFF97316),
          itemIndex: 8,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required _Palette p,
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required int itemIndex,
    bool isImportant = false,
    VoidCallback? onTap,
  }) {
    final showSkeleton = _loading && !_hasLoadedOnce;

    return _Entry(
      animation: _entryController,
      index: itemIndex,
      from: const Offset(0, 30),
      child: Semantics(
        button: onTap != null,
        label: '$label: ${_ku(value)}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap == null
                ? null
                : () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Container(
              // ✅ پادینگی ناوەوە کەمکرایەوە بۆ ئەوەی بۆشایی زیاتر بۆ دەق بمێنێت
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isImportant
                      ? color.withValues(alpha: 0.5)
                      : color.withValues(alpha: 0.15),
                  width: isImportant ? 2 : 1.2,
                ),
                boxShadow: [
                  ...p.shadow(),
                  if (isImportant)
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const Spacer(),
                      if (isImportant)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: _pulseAnimation.value * 0.8,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (onTap != null)
                        Icon(Icons.north_west_rounded,
                            size: 14, color: p.chevron),
                    ],
                  ),
                  // ✅ بەشی خوارەوە (ژمارە و ناو) بە FittedBox
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSkeleton)
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            final t = (_shimmerController.value * 2) % 2;
                            final a = 0.12 + 0.12 * (t < 1 ? t : 2 - t);
                            return Container(
                              width: 54,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: a),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          },
                        )
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: value.toDouble()),
                            duration: _reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => Text(
                              tr(_ku(v.round())),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: color,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          tr(label),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: p.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(_Palette p, _DashItem item) {
    final badge = item.badge;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: '${item.title}. ${item.subtitle}'
            '${badge != null && badge > 0 ? '. ${_ku(badge)}' : ''}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(item);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.important
                      ? item.color.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: item.important ? 1.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          item.color.withValues(alpha: 0.2),
                          item.color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tr(item.title),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: p.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (badge != null && badge > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: item.color,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  tr(_ku(badge)),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(item.subtitle),
                          style: TextStyle(fontSize: 11, color: p.textSub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, size: 20, color: p.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
