// lib/widgets/weather_widget_ui.dart
// ڕووکاری _WeatherWidgetState — لە weather_widget.dart جیاکراوەتەوە

part of 'weather_widget.dart';

extension _WeatherWidgetStateUi on _WeatherWidgetState {
  Widget _sectionTitle(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _WeatherWidgetState._accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(text),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _text(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌡️ کارتی ئێستا
  // ═══════════════════════════════════════════════════════════
  Widget _buildCurrentCard(WeatherSnapshot snap, bool refreshing, bool failed) {
    final c = snap.current;
    final cond = _condition(c);
    final colors = _gradient(c);
    final today = snap.today;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors[1].withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── سەرەوە ───
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 12),
              ),
              const SizedBox(width: 6),
              Text(
                _t('location'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.official
                      ? Colors.amber.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tr(c.official ? _t('official') : _t('live')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (failed)
                Tooltip(
                  message: _t('offline'),
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 6),
                    child: Icon(Icons.cloud_off_rounded,
                        color: Colors.amberAccent, size: 13),
                  ),
                ),
              Icon(Icons.access_time_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 11),
              const SizedBox(width: 3),
              Text(
                tr(_hm(c.updatedAt)),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              _RefreshButton(
                spinning: refreshing,
                tooltip: _t('refresh'),
                onTap: refreshing ? null : _manualRefresh,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── پلەی گەرمی و ئایکۆن ───
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(_n(c.temp)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            '°C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      tr(cond.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RepaintBoundary(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(tr(cond.emoji),
                          style: const TextStyle(fontSize: 50)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── وردەکاری ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _detail(
                    Icons.water_drop_rounded,
                    _t('humidity'),
                    c.humidity == null ? '--' : '${_n(c.humidity!)}%',
                  ),
                ),
                _vDivider(),
                Expanded(
                  child: _detail(
                    Icons.air_rounded,
                    _t('wind'),
                    c.wind == null ? '--' : '${_n(c.wind!)} ${_t('kmh')}',
                  ),
                ),
                _vDivider(),
                Expanded(
                  child: _detail(
                    Icons.speed_rounded,
                    _t('pressure'),
                    c.pressure == null ? '--' : '${_n(c.pressure!)} hPa',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── هەست پێکراو + بەرز/نزم ───
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (c.feels != null)
                _pill(
                  Icons.thermostat_rounded,
                  '${_t('feels')}: ${_n(c.feels!)}°',
                ),
              if (today != null)
                _pill(
                  Icons.swap_vert_rounded,
                  '${_n(today.max)}° / ${_n(today.min)}°',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            tr(text),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
        const SizedBox(height: 6),
        Text(
          tr(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tr(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 40,
    color: Colors.white.withValues(alpha: 0.2),
  );

  // ═══════════════════════════════════════════════════════════
  // 🕐 پێشبینی کاتژمێری
  // ═══════════════════════════════════════════════════════════
  Widget _buildHourly(List<WeatherHour> hours, bool isDark) {
    final list = hours.take(24).toList();

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final h = list[i];
          final isNow = i == 0;
          final cond = WeatherService.conditionOf(h.code, h.temp, h.isDay);
          final rain = h.rainChance;
          final fg = isNow ? Colors.white : _text(isDark);

          return Container(
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: isNow
                ? BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _WeatherWidgetState._accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            )
                : _surface(isDark, radius: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr(isNow ? _t('now') : _hm(h.time)),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isNow ? Colors.white : _sub(isDark),
                    height: 1.2,
                  ),
                ),
                Text(tr(cond.emoji),
                    style: const TextStyle(fontSize: 24, height: 1.2)),
                Text(
                  '${_n(h.temp)}°',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: fg,
                    height: 1.2,
                  ),
                ),
                Text(
                  tr((rain != null && rain >= 20) ? '💧${_n(rain)}%' : ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isNow ? Colors.white : const Color(0xFF29B6F6),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ☀️ خۆرهەڵاتن / خۆرئاوابوون
  // ═══════════════════════════════════════════════════════════
  List<Widget> _buildSunSection(WeatherSnapshot snap, bool isDark) {
    final today = snap.today;
    final rise = today?.sunrise;
    final set = today?.sunset;
    if (rise == null || set == null || !set.isAfter(rise)) return const [];

    final now = snap.nowEstimate;
    final total = set.difference(rise);
    final p =
    (now.difference(rise).inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final isDayNow = now.isAfter(rise) && now.isBefore(set);
    final daylight =
        '${total.inHours}:${(total.inMinutes % 60).toString().padLeft(2, '0')}';

    Widget end(IconData icon, String label, String value, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(tr(value),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _text(isDark))),
          Text(tr(label),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _sub(isDark))),
        ],
      );
    }

    return [
      _sectionTitle(Icons.wb_sunny_rounded, _t('sun'), isDark),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: _surface(isDark),
        child: Column(
          children: [
            Row(
              children: [
                end(Icons.wb_twilight_rounded, _t('sunrise'), _hm(rise),
                    const Color(0xFFFFA000)),
                const Spacer(),
                end(Icons.hourglass_bottom_rounded, _t('daylight'),
                    _n(daylight), _WeatherWidgetState._accent),
                const Spacer(),
                end(Icons.nights_stay_rounded, _t('sunset'), _hm(set),
                    const Color(0xFFF4511E)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 28,
              child: LayoutBuilder(
                builder: (context, cons) {
                  const dot = 28.0;
                  final x = (cons.maxWidth - dot) * p;
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              begin: AlignmentDirectional.centerStart,
                              end: AlignmentDirectional.centerEnd,
                              colors: [
                                Color(0xFFFFCA28),
                                Color(0xFFFFA000),
                                Color(0xFFF4511E),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: x,
                        top: 0,
                        child: Container(
                          width: dot,
                          height: dot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDayNow
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF3949AB),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            isDayNow
                                ? Icons.wb_sunny_rounded
                                : Icons.nightlight_round,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 وردەکاری
  // ═══════════════════════════════════════════════════════════
  Widget _buildDetailsGrid(WeatherSnapshot snap, bool isDark) {
    final c = snap.current;
    final today = snap.today;
    final uv = c.uv ?? today?.uvMax;
    final uvL = uv == null ? null : _uvLevel(uv);
    final vis = c.visibilityKm;
    final rainMm = today?.rainMm;

    final tiles = <Widget>[
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.wb_sunny_rounded),
        color: const Color(0xFFFFA000),
        label: _t('uv'),
        value: uv == null ? '--' : _n(uv.round()),
        sub: uvL?.text,
        subColor: uvL?.color,
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.visibility_rounded),
        color: const Color(0xFF26A69A),
        label: _t('visibility'),
        value: vis == null ? '--' : '${_n(_fmt1(vis))} ${_t('km')}',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.storm_rounded),
        color: const Color(0xFF5C6BC0),
        label: _t('gust'),
        value: c.gust == null ? '--' : '${_n(c.gust!)} ${_t('kmh')}',
      ),
      _tile(
        isDark: isDark,
        icon: Transform.rotate(
          // ئاراستەی با = ئەو لایەی لێیەوە دێت، تیرەکە بەرەو کوێ دەڕوات
          angle: ((c.windDir ?? 0) + 180) * math.pi / 180,
          child: const Icon(Icons.navigation_rounded),
        ),
        color: const Color(0xFF29B6F6),
        label: _t('wind_dir'),
        value: c.windDir == null ? '--' : _compass(c.windDir!),
        sub: c.windDir == null ? null : '${_n(c.windDir!)}°',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.cloud_rounded),
        color: const Color(0xFF78909C),
        label: _t('cloud'),
        value: c.cloud == null ? '--' : '${_n(c.cloud!)}%',
      ),
      _tile(
        isDark: isDark,
        icon: const Icon(Icons.umbrella_rounded),
        color: const Color(0xFF1E88E5),
        label: _t('rain'),
        value: rainMm == null ? '--' : '${_n(_fmt1(rainMm))} ${_t('mm')}',
        sub: today?.rainChance == null
            ? null
            : '${_t('rain_chance')}: ${_n(today!.rainChance!)}%',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _grid(tiles),
    );
  }

  Widget _grid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, cons) {
        final w = (cons.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  Widget _tile({
    required bool isDark,
    required Widget icon,
    required Color color,
    required String label,
    required String value,
    String? sub,
    Color? subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _surface(isDark, radius: 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: color, size: 22),
                child: icon,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _sub(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _text(isDark),
                  ),
                ),
                // هەمیشە هەیە تا هەموو خانەکان هەمان بەرزییان هەبێت
                Text(
                  tr(sub ?? ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: subColor ?? _sub(isDark),
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
  // 🌫️ کوالیتی هەوا
  // ═══════════════════════════════════════════════════════════
  Widget _buildAir(AirQuality a, bool isDark) {
    final lvl = _aqiLevel(a.aqi);
    final dusty = (a.dust ?? 0) >= 100;

    Widget stat(String label, double? v) => Column(
      children: [
        Text(
          tr(v == null ? '--' : _n(v.round())),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _text(isDark),
          ),
        ),
        Text(tr(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _sub(isDark))),
        Text('µg/m³',
            style: TextStyle(fontSize: 9, color: _sub(isDark))),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _surface(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lvl.color.withValues(alpha: 0.15),
                  border: Border.all(color: lvl.color, width: 2),
                ),
                child: Center(
                  child: Text(
                    tr(_n(a.aqi)),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: lvl.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(lvl.text),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: lvl.color,
                      ),
                    ),
                    Text('US AQI',
                        style: TextStyle(fontSize: 11, color: _sub(isDark))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AqiBar(aqi: a.aqi),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: stat('PM2.5', a.pm25)),
              Expanded(child: stat('PM10', a.pm10)),
              Expanded(child: stat(_t('dust'), a.dust)),
            ],
          ),
          if (dusty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA000).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFA000).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFFA000), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t('dust_alert'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _text(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📅 پێشبینی ٧ ڕۆژ
  // ═══════════════════════════════════════════════════════════
  Widget _buildForecast(WeatherSnapshot snap, bool isDark) {
    final now = snap.nowEstimate;
    final weekMin = snap.days.map((d) => d.min).reduce(math.min);
    final weekMax = snap.days.map((d) => d.max).reduce(math.max);
    final span = math.max(1, weekMax - weekMin);

    return Column(
      children: snap.days.map((day) {
        final isToday = WeatherSnapshot.isSameDay(day.date, now);
        final cond = WeatherService.conditionOf(day.code, day.max, true);

        final bgColor = isToday
            ? _WeatherWidgetState._accent.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark ? const Color(0xFF1A1A22) : Colors.white);
        final borderColor =
        isToday ? _WeatherWidgetState._accent.withValues(alpha: 0.3) : Colors.transparent;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openDay(day, now),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // ١. ناوی ڕۆژ
                SizedBox(
                  width: 84,
                  child: Text(
                    tr(_dayName(day, now)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.bold,
                      color: isToday
                          ? _WeatherWidgetState._accent
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                // ٢. ئایکۆن + ئەگەری باران
                SizedBox(
                  width: 30,
                  child: Text(tr(cond.emoji), style: const TextStyle(fontSize: 22)),
                ),
                SizedBox(
                  width: 38,
                  child: (day.rainChance != null && day.rainChance! >= 30)
                      ? Text(
                    '${_n(day.rainChance!)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF29B6F6),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
                // ٣. نزم — هێڵی مەودا — بەرز
                SizedBox(
                  width: 30,
                  child: Text(
                    '${_n(day.min)}°',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RangeBar(
                    start: (day.min - weekMin) / span,
                    end: (day.max - weekMin) / span,
                    from: _WeatherWidgetState._tempColor(day.min),
                    to: _WeatherWidgetState._tempColor(day.max),
                    track: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${_n(day.max)}°',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _placeholderDecoration(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t('loading'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _placeholderDecoration().copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF90A4AE), Color(0xFF546E7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              _t('error'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _t('error_sub'),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _t('retry'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
