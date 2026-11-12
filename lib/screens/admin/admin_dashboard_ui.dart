// lib/screens/admin/admin_dashboard_ui.dart
// ڕووکاری _AdminDashboardScreenState — لە admin_dashboard.dart جیاکراوەتەوە

part of 'admin_dashboard.dart';

extension _AdminDashboardScreenStateUi on _AdminDashboardScreenState {
  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isAdmin) {
    final hasError = _loadError != null;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: dark ? _kAppBarColor : AppColors.primary,
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? const [Color(0xFF1A1B2E), Color(0xFF232334)]
                  : const [Color(0xFF1565C0), Color(0xFF1E88E5)],
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
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
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
                              tr(isAdmin
                                  ? 'پانێڵی ئەدمین'
                                  : 'پانێڵی بەڕێوەبردن'),
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
                                          ? const Color(0xFFD9822B)
                                          : const Color(0xFF0F9D7A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      tr(hasError
                                          ? (_lastUpdated == null
                                              ? 'کێشەی پەیوەندی'
                                              : trf(
                                                  'کێشەی پەیوەندی • دوایین نوێکردنەوە {0}',
                                                  [
                                                      _lastUpdatedText
                                                    ]))
                                          : (_lastUpdated == null
                                              ? 'سیستەم چالاکە'
                                              : trf('سیستەم چالاکە • {0}',
                                                  [_lastUpdatedText]))),
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
          color: const Color(0xFFD9822B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFD9822B).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFD9822B), size: 20),
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
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
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
              colors: [Color(0xFFDC3545), Color(0xFFE35D6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC3545).withValues(alpha: 0.35),
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
      colors: const [Color(0xFF0F9D7A), Color(0xFF0F9D7A)],
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
  /// ئاماری سەرەکی: یەک کارت بە چوار ژمارە (چاوەڕوانەکان لە بانەری سەرەوەن)
  Widget _buildStatsStrip(_Palette p, bool isAdmin) {
    final loading = _loading && !_hasLoadedOnce;

    Widget stat(IconData icon, String label, int value, VoidCallback onTap) {
      return Expanded(
        child: Semantics(
          button: true,
          label: '$label: ${loading ? '' : _ku(value)}',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    loading ? '…' : _ku(value),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.textSub),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget divider() => Container(width: 1, height: 44, color: p.border);

    return _Entry(
      animation: _entryController,
      index: 3,
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: p.shadow(0.05),
        ),
        child: Row(
          children: [
            stat(Icons.storefront_rounded, tr('شوێنەکان'), _totalStores,
                () => _push(const AdminStoresScreen())),
            divider(),
            stat(Icons.account_balance_rounded, tr('فەرمانگەکان'),
                _totalDepartments, () => _push(const AdminDepartmentsScreen())),
            divider(),
            stat(Icons.assignment_rounded, tr('سکاڵاکان'), _totalComplaints,
                () => _push(const AdminComplaintsProScreen())),
            divider(),
            stat(Icons.newspaper_rounded, tr('هەواڵەکان'), _totalNews,
                () => _push(const AdminNewsScreen())),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_Palette p, _DashItem item) {
    final badge = item.badge ?? 0;
    final urgent = item.important && badge > 0;

    return Semantics(
      button: true,
      label: '${item.title}. ${item.subtitle}'
          '${badge > 0 ? '. ${_ku(badge)}' : ''}',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _open(item);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: p.isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: p.textSub),
                    ),
                  ],
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                urgent
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _ku(badge),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : Text(
                        _ku(badge),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: p.textSub,
                        ),
                      ),
              ],
              const SizedBox(width: 4),
              Icon(
                AppLang.isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 22,
                color: p.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
