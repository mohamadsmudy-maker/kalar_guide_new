import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../services/prayer/kalar_prayer_times.dart';
import '../../services/prayer/prayer_reminders.dart';
import 'prayer_month_share.dart';
import '../../l10n/tr.dart';

/// 📅 بینینی هەفتانە و مانگانەی کاتەکانی نوێژ — ULTRA PRO
class PrayerWeeklyView extends StatefulWidget {
  final double lat;
  final double lng;
  final String locationName;

  const PrayerWeeklyView({
    super.key,
    required this.lat,
    required this.lng,
    this.locationName = 'کەلار',
  });

  @override
  State<PrayerWeeklyView> createState() => _PrayerWeeklyViewState();
}

class _PrayerWeeklyViewState extends State<PrayerWeeklyView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _weekData = [];
  List<Map<String, dynamic>> _monthData = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _kurdishDigits = false;

  static const List<String> _months = [
    'کانوونی دووەم',
    'شوبات',
    'ئازار',
    'نیسان',
    'ئایار',
    'حوزەیران',
    'تەممووز',
    'ئاب',
    'ئەیلوول',
    'تشرینی یەکەم',
    'تشرینی دووەم',
    'کانوونی یەکەم',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    PrayerReminderSettings.load().then((s) {
      if (mounted) setState(() => _kurdishDigits = s.kurdishDigits);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// هەمان سەرچاوەی شاشەی سەرەکی (خشتەی فەرمی یان هەژماری ڕێکخراو)،
  /// بۆیە پێویستی بە ئینتەرنێت نییە و هەردوو شاشە هەمان کات پیشان دەدەن.
  Future<void> _loadData() async {
    final days = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final allDays = <Map<String, dynamic>>[
      for (var d = 1; d <= days; d++) _dayData(DateTime(_selectedYear, _selectedMonth, d)),
    ];

    final today = DateTime.now();
    final weekStart = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final week = <Map<String, dynamic>>[
      for (var d = weekStart; !d.isAfter(weekEnd); d = DateTime(d.year, d.month, d.day + 1))
        _dayData(d),
    ];

    if (!mounted) return;
    setState(() {
      _weekData = week;
      _monthData = allDays;
      _loading = false;
    });
  }

  static const List<String> _hijriMonthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  Map<String, dynamic> _dayData(DateTime date) {
    final t = KalarPrayerTimes.forDay(date, lat: widget.lat, lng: widget.lng).times;
    final hijri = HijriCalendar.fromDate(date);
    return {
      'date': {
        'gregorian': {'date': KalarPrayerTimes.dateKey(date)},
        'hijri': {
          'day': '${hijri.hDay}',
          'month': {'ar': _hijriMonthsAr[hijri.hMonth - 1]},
        },
      },
      'timings': {
        'Fajr': t['fajr'],
        'Sunrise': t['sunrise'],
        'Dhuhr': t['dhuhr'],
        'Asr': t['asr'],
        'Maghrib': t['maghrib'],
        'Isha': t['isha'],
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              actions: [
                IconButton(
                  tooltip: tr('هاوبەشکردنی خشتەی مانگ'),
                  icon: const Icon(Icons.ios_share_rounded, color: Color(0xFFFFD700)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrayerMonthSharePage(
                        year: _selectedYear,
                        month: _selectedMonth,
                        monthName: tr(_months[_selectedMonth - 1]),
                        lat: widget.lat,
                        lng: widget.lng,
                        kurdishDigits: _kurdishDigits,
                      ),
                    ),
                  ),
                ),
              ],
              backgroundColor: const Color(0xFF1A1B2E),
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A1B2E), Color(0xFF2D1B4E)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFFFD700).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFFFFD700),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tr('بینینی هەفتانە و مانگانە'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${tr(widget.locationName)} • ${tr(_months[_selectedMonth - 1])} $_selectedYear',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1421),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: const Color(0xFF0F1421),
                      unselectedLabelColor: Colors.white60,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        height: 1.0,
                      ),
                      tabs: [
                        Tab(
                          height: 36,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.view_week_rounded, size: 14),
                                const SizedBox(width: 4),
                                Text(tr('حەوت ڕۆژ')),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          height: 36,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_view_month_rounded, size: 14),
                                const SizedBox(width: 4),
                                Text(tr('مانگانە')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: _loading
              ? const Center(
            child:
            CircularProgressIndicator(color: Color(0xFFFFD700)),
          )
              : TabBarView(
            controller: _tabController,
            children: [
              _buildWeekView(),
              _buildMonthView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekView() {
    if (_weekData.isEmpty) {
      return _buildEmpty(tr('هیچ داتایەک نییە بۆ ئەم هەفتەیە'));
    }

    final today = DateTime.now();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _weekData.length,
      itemBuilder: (context, index) {
        final day = _weekData[index];
        final date = _parseDate(day['date']['gregorian']['date']);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;

        return _buildDayCard(day, isToday);
      },
    );
  }

  Widget _buildMonthView() {
    if (_monthData.isEmpty) {
      return _buildEmpty(tr('هیچ داتایەک نییە بۆ ئەم مانگە'));
    }

    final today = DateTime.now();

    return Column(
      children: [
        // ⭐ Month Selector
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFFFD700),
                ),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth > 1) {
                      _selectedMonth--;
                    } else {
                      _selectedMonth = 12;
                      _selectedYear--;
                    }
                  });
                  _loadData();
                },
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2030),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${tr(_months[_selectedMonth - 1])} $_selectedYear',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFFFFD700),
                ),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth < 12) {
                      _selectedMonth++;
                    } else {
                      _selectedMonth = 1;
                      _selectedYear++;
                    }
                  });
                  _loadData();
                },
              ),
            ],
          ),
        ),

        // ⭐ Days Grid
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _monthData.length,
            itemBuilder: (context, index) {
              final day = _monthData[index];
              final date = _parseDate(day['date']['gregorian']['date']);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return _buildDayCard(day, isToday, compact: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day, bool isToday,
      {bool compact = false}) {
    final gregorian = day['date']['gregorian'];
    final hijri = day['date']['hijri'];
    final timings = day['timings'];

    final date = _parseDate(gregorian['date']);
    final dayName = _getDayName(date.weekday);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isToday
            ? LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.2),
            const Color(0xFFFFB300).withValues(alpha: 0.05),
          ],
        )
            : null,
        color: isToday ? null : const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFFD700).withValues(alpha: 0.5)
              : const Color(0xFF2A3244),
          width: isToday ? 2 : 1,
        ),
        boxShadow: isToday
            ? [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFFFFD700)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr(dayName),
                  style: TextStyle(
                    color: isToday
                        ? const Color(0xFF0F1421)
                        : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr(gregorian['date']),
                style: TextStyle(
                  color: isToday ? const Color(0xFFFFD700) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tr('🔥 ئەمڕۆ'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${hijri['day']} ${hijri['month']['ar']}',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimeChip(tr('بەیانی'), timings['Fajr'],
                  Icons.nights_stay_rounded, const Color(0xFF5E5CE6)),
              _buildTimeChip(tr('نیوەڕۆ'), timings['Dhuhr'],
                  Icons.wb_sunny_rounded, const Color(0xFFFF8F00)),
              _buildTimeChip(tr('عەسر'), timings['Asr'],
                  Icons.wb_sunny_outlined, const Color(0xFF29B6F6)),
              _buildTimeChip(tr('مەغریب'), timings['Maghrib'],
                  Icons.wb_twilight_rounded, const Color(0xFFEF5350)),
              _buildTimeChip(tr('عیشا'), timings['Isha'],
                  Icons.nightlight_round, const Color(0xFF7986CB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String name, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            tr(name),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tr(KalarPrayerTimes.format12(time, kurdishDigits: _kurdishDigits)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            color: Colors.white24,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            tr(message),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return DateTime.now();
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'دوشەممە',
      'سێشەممە',
      'چوارشەممە',
      'پێنجشەممە',
      'هەینی',
      'شەممە',
      'یەکشەممە',
    ];
    return tr(days[(weekday - 1) % 7]);
  }
}