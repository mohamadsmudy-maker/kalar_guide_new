// lib/screens/daily/prayer_times_screen_ui.dart
// ڕووکاری _PrayerTimesScreenState — لە prayer_times_screen.dart جیاکراوەتەوە

part of 'prayer_times_screen.dart';

extension _PrayerTimesScreenStateUi on _PrayerTimesScreenState {
  // ═══════════════════════════════════════════════════════════
  // 🎨 Top Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: tr('گەڕانەوە'),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('کاتەکانی نوێژ'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tr('ئەپی ڕێبەری کەلار'),
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _topIcon(
            _isPlayingAdhan ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
            _isPlayingAdhan ? 'وەستاندنی ئەزان' : 'گوێگرتن لە ئەزان',
            _toggleAdhan,
            active: _isPlayingAdhan,
          ),
          _topIcon(Icons.settings_rounded, 'ڕێکخستنی نوێژ', _openSettings),
          _topIcon(Icons.calendar_month_rounded, 'خشتەی هەفتانە', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PrayerWeeklyView(lat: _lat, lng: _lng)),
            );
          }),
          _topIcon(Icons.explore_rounded, 'قیبلە', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QiblaFinderScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, String tooltip, VoidCallback onTap, {bool active = false}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: active ? AppColors.red.withValues(alpha: 0.2) : Colors.transparent,
      ),
      icon: Icon(icon, color: active ? AppColors.red : AppColors.orange, size: 22),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(_errorMessage!),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 Date Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.orange.withValues(alpha: 0.18),
            AppColors.orange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.orange, AppColors.yellow]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _digits(tr(_hijriDate)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _badge(
                      _isOfficial ? 'فەرمی' : 'هەژمارکراو',
                      _isOfficial ? AppColors.green : AppColors.yellow,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _digits(_gregorianDate),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.location_on_rounded, color: AppColors.orange, size: 16),
          const SizedBox(width: 3),
          Text(
            tr('کەلار'),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tr(text),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⏱️ Countdown Card — تەنها ئەم بەشە هەموو چرکەیەک نوێ دەبێتەوە
  // ═══════════════════════════════════════════════════════════
  Widget _buildCountdownCard() {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.darkCard, AppColors.darkSurface],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.25), width: 1.2),
        ),
        child: ValueListenableBuilder<_Countdown>(
          valueListenable: _countdown,
          builder: (context, cd, _) {
            final r = cd.remaining;
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time_filled_rounded,
                          color: AppColors.orange, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        trf('نوێژی داهاتوو: {0}', [cd.nextName]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: trf('ماوە: {0} سەعات و {1} خولەک', [r.inHours, r.inMinutes % 60]),
                  excludeSemantics: true,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Expanded(child: _timeBox(_digits(_PrayerTimesScreenState._two(r.inHours)), 'سەعات')),
                        _colon(),
                        Expanded(child: _timeBox(_digits(_PrayerTimesScreenState._two(r.inMinutes % 60)), 'خولەک')),
                        _colon(),
                        Expanded(child: _timeBox(_digits(_PrayerTimesScreenState._two(r.inSeconds % 60)), 'چرکە')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: cd.progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _timeBox(String v, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orange, AppColors.yellow],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(v),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          tr(label),
          maxLines: 1,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _colon() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 18),
      child: Text(
        ':',
        style: TextStyle(
          color: AppColors.orange.withValues(alpha: 0.6),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌙 Ramadan Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildRamadanCard() {
    String? time(String id) {
      for (final p in _prayers) {
        if (p.id == id) return p.time;
      }
      return null;
    }

    final suhoor = time('fajr');
    final iftar = time('maghrib');
    if (suhoor == null || iftar == null) return const SizedBox.shrink();
    final dayOfRamadan = HijriCalendar.fromDate(DateTime.now()).hDay;

    Widget column(String label, String hm, IconData icon) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: AppColors.yellow, size: 20),
              const SizedBox(height: 4),
              Text(tr(label),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(tr(_formatDisplay(hm)),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.purple.withValues(alpha: 0.35), AppColors.darkCard],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '🌙 ڕەمەزانی پیرۆز — ڕۆژی ${_digits('$dayOfRamadan')}',
            style: const TextStyle(color: AppColors.yellow, fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              column('کۆتایی پارشێو', suhoor, Icons.nightlight_round),
              Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.1)),
              column('بەربانگ', iftar, Icons.wb_twilight_rounded),
            ],
          ),
          const SizedBox(height: 10),
          // هەموو چرکەیەک لەگەڵ کاونتداونەکە نوێ دەبێتەوە
          ValueListenableBuilder<_Countdown>(
            valueListenable: _countdown,
            builder: (context, cd, child) {
              final now = DateTime.now();
              final s = _Prayer('fajr', '', suhoor, Icons.circle, AppColors.yellow).on(now);
              final i = _Prayer('maghrib', '', iftar, Icons.circle, AppColors.yellow).on(now);
              final String text;
              if (now.isBefore(s)) {
                text = trf('{0} ماوە بۆ کۆتایی پارشێو', [_left(s.difference(now))]);
              } else if (now.isBefore(i)) {
                text = trf('{0} ماوە بۆ بەربانگ', [_left(i.difference(now))]);
              } else {
                text = 'بەربانگت پیرۆز بێت 🤲';
              }
              return Text(
                tr(text),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              );
            },
          ),
        ],
      ),
    );
  }

  String _left(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final hs = h > 0 ? '${_digits('$h')} سەعات و ' : '';
    return '$hs${_digits('$m')} خولەک';
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Section Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr('کاتەکانی نوێژ'),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🕌 Prayer Tile
  // ═══════════════════════════════════════════════════════════
  Widget _buildPrayerTile(_Prayer prayer) {
    final color = prayer.color;
    final isNext = _countdown.value.nextId == prayer.id;
    final isCurrent = !isNext && _currentId == prayer.id;
    final isPassed = !isNext && !isCurrent && _isPassed(prayer);
    final dim = Colors.white.withValues(alpha: 0.35);

    final iconBox = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isNext ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        prayer.icon,
        color: isNext ? Colors.white : (isPassed ? color.withValues(alpha: 0.4) : color),
        size: 22,
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isNext
            ? LinearGradient(
                colors: [
                  AppColors.orange.withValues(alpha: 0.85),
                  AppColors.orange.withValues(alpha: 0.5),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              )
            : const LinearGradient(colors: [AppColors.darkCard, AppColors.darkSurface]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? AppColors.orange
              : isCurrent
                  ? AppColors.green.withValues(alpha: 0.7)
                  : (isPassed ? Colors.white.withValues(alpha: 0.05) : AppColors.darkBorder),
          width: isNext || isCurrent ? 1.3 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          isNext ? ScaleTransition(scale: _pulseAnim, child: iconBox) : iconBox,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(prayer.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPassed ? dim : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(height: 3),
                  _badge('داهاتوو', Colors.white),
                ] else if (isCurrent) ...[
                  const SizedBox(height: 3),
                  _badge('کاتی ئێستا', AppColors.green),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isNext
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isPassed ? Colors.white.withValues(alpha: 0.04) : color.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isNext ? Colors.white.withValues(alpha: 0.4) : color.withValues(alpha: 0.22),
                  ),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    tr(_formatDisplay(prayer.time)),
                    style: TextStyle(
                      color: isNext ? Colors.white : (isPassed ? dim : color),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Loading / Error
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            tr('خەریکی هێنانی کاتەکان...'),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 56),
            const SizedBox(height: 16),
            Text(
              tr(_errorMessage ?? 'هەڵە'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('دووبارە')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
