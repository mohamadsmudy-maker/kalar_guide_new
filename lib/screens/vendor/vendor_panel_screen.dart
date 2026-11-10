// lib/screens/vendor/vendor_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/auth_service.dart';
import '../../services/currency_pdf_service.dart';
import '../../services/currency_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../services/fuel_service.dart';
import '../../widgets/multi_currency_chart_widget.dart';
import '../../widgets/multi_fuel_chart_widget.dart';
import '../../utils/place_display.dart';
import '../admin/admin_dashboard.dart';
import '../currency/currency_station_details_screen.dart';
import '../fuel/station_details_screen.dart';
import 'vendor_place_dashboard.dart';

/// 🏪 «پانێڵەکەم» — ڤێندەری بەنزینخانە یان نوسینگەی دراو
///
/// شوێنەکانی خۆی (بە store_id یان ژمارەی تەلەفۆن) پیشان دەدات و بە یەک
/// کرتە دەچێتە شاشەی شوێنەکە، کە گۆڕینی نرخ و مێژووی نرخەکانی تێدایە.
/// هەمان یاسای مۆڵەتی Supabase بەکاردێت ([AuthSessionManager.canEditStation]).
class VendorPanelScreen extends StatefulWidget {
  const VendorPanelScreen({super.key});

  @override
  State<VendorPanelScreen> createState() => _VendorPanelScreenState();
}

enum _Kind { fuel, currency, other }

class _VendorPanelScreenState extends State<VendorPanelScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sid = AuthSessionManager.storeId?.toString() ?? '';
      final key = AuthSessionManager.phoneKey(AuthSessionManager.currentUser?['phone']);
      final filters = <String>[
        if (int.tryParse(sid) != null) 'id.eq.$sid',
        // ٩ ژمارەی کۆتایی — دواتر بە phoneKey ڕێک بەراورد دەکرێت
        if (key.length == 10) 'phone.ilike.*${key.substring(1)}*',
      ];
      var rows = <Map<String, dynamic>>[];
      if (filters.isNotEmpty) {
        final res = await Supabase.instance.client
            .from('dukan')
            .select('id, name, phone, address, description, logo, image, category, sub_category, '
                'fuel_prices, currency_prices')
            .or(filters.join(','))
            .order('name');
        rows = List<Map<String, dynamic>>.from(res as List)
            .where((r) => AuthSessionManager.canEditStation(stationId: r['id'], stationPhone: r['phone']))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _places = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  static _Kind _kindOf(Map<String, dynamic> p) {
    final cat = '${p['category'] ?? ''} ${p['sub_category'] ?? ''}';
    final cur = p['currency_prices'];
    final fuel = p['fuel_prices'];
    if ((cur is Map && cur.isNotEmpty) || cat.contains('دراو') || cat.contains('سەرافی')) {
      return _Kind.currency;
    }
    if ((fuel is Map && fuel.isNotEmpty) || FuelService.isStation(p)) return _Kind.fuel;
    return _Kind.other;
  }

  int _priceCount(Map<String, dynamic> p, _Kind k) {
    final m = k == _Kind.fuel ? p['fuel_prices'] : p['currency_prices'];
    return m is Map ? m.length : 0;
  }

  Future<void> _open(Map<String, dynamic> p, _Kind k) async {
    HapticFeedback.selectionClick();
    final id = int.tryParse('${p['id']}');
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            k == _Kind.currency ? CurrencyStationDetailsScreen(stationId: id) : StationDetailsScreen(stationId: id),
      ),
    );
    if (mounted) _load();
  }

  Future<List<Map<String, dynamic>>> _history(Map<String, dynamic> p, _Kind k) async {
    final id = int.tryParse('${p['id']}');
    if (id == null) return [];
    return k == _Kind.currency
        ? CurrencyService.getStationPriceHistory(stationId: id)
        : FuelService.getStationPriceHistory(stationId: id);
  }

  /// 📈 چارتی نرخەکانی تەنها ئەم شوێنە
  Future<void> _openChart(Map<String, dynamic> p, _Kind k) async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VendorChartScreen(
          title: tr(p['name']?.toString() ?? ''),
          load: () => _history(p, k),
          isCurrency: k == _Kind.currency,
        ),
      ),
    );
  }

  /// 📄 ڕاپۆرتی PDF ی مێژووی نرخەکانی ئەم شوێنە
  bool _pdfBusy = false;
  Future<void> _pdf(Map<String, dynamic> p, _Kind k) async {
    if (_pdfBusy) return;
    HapticFeedback.selectionClick();
    setState(() => _pdfBusy = true);
    try {
      final history = await _history(p, k);
      if (!mounted) return;
      if (history.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('هێشتا هیچ مێژوویەکی نرخ نییە'))),
        );
        return;
      }
      final title = trf('ڕاپۆرتی نرخەکانی {0}', [p['name']?.toString() ?? '']);
      if (k == _Kind.currency) {
        await CurrencyPdfService.generateMultiReport(context: context, allHistory: history, title: title);
      } else {
        DateTime oldest = DateTime.now();
        for (final h in history) {
          final t = DateTime.tryParse('${h['created_at'] ?? ''}');
          if (t != null && t.isBefore(oldest)) oldest = t;
        }
        await FuelPdfService.generateDateRangeReport(
          context: context,
          fromDate: oldest,
          toDate: DateTime.now(),
          history: history,
          title: title,
        );
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF2F5FA);
    final name = AuthSessionManager.userName ?? '';

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(tr('پانێڵەکەم'), style: const TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: tr('نوێکردنەوە'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _welcome(name),
              const SizedBox(height: 18),
              if (_places.length != 1)
                Text(
                  tr('شوێنەکانم'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _note(isDark, Icons.wifi_off_rounded, tr('هەڵە لە هێنانی زانیاری'), AppColors.toneRed)
              else if (_places.isEmpty)
                _note(
                  isDark,
                  Icons.link_off_rounded,
                  tr('هیچ شوێنێک بە ئەکاونتەکەتەوە نەبەستراوە. ژمارەی تەلەفۆنی شوێنەکەت دەبێت وەک ژمارەی ئەکاونتەکەت بێت، یان پەیوەندی بە ئەدمینەوە بکە.'),
                  AppColors.toneAmber,
                )
              else if (_places.length == 1)
                // یەک شوێن: داشبۆردەکە ڕاستەوخۆ
                _dashboard(_places.first)
              else
                for (final p in _places) _placeCard(p, isDark),
              const SizedBox(height: 18),
              _moreTile(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome(String name) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF1E3A5F)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? tr('بەخێربێیت') : trf('بەخێربێیت، {0}', [name]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('نرخ، هەواڵ و زانیاری شوێنەکەت لێرەوە بەڕێوەببە'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  (Color, IconData, String) _style(_Kind k) => switch (k) {
        _Kind.fuel => (AppColors.toneAmber, Icons.local_gas_station_rounded, tr('بەنزینخانە')),
        _Kind.currency => (AppColors.toneTeal, Icons.currency_exchange_rounded, tr('نوسینگەی دراو')),
        _Kind.other => (AppColors.toneBlue, Icons.storefront_rounded, tr('شوێن')),
      };

  Widget _dashboard(Map<String, dynamic> p) {
    final k = _kindOf(p);
    final (color, icon, label) = _style(k);
    return VendorPlaceDashboard(
      key: ValueKey('dash-${p['id']}'),
      place: p,
      kindLabel: label,
      icon: icon,
      color: color,
      prices: k == _Kind.other
          ? null
          : VendorPriceActions(
              onPrices: () => _open(p, k),
              onChart: () => _openChart(p, k),
              onPdf: _pdfBusy ? null : () => _pdf(p, k),
              pdfBusy: _pdfBusy,
            ),
    );
  }

  /// چەند شوێن: کارتێکی کورت؛ کرتە → داشبۆردی ئەو شوێنە
  Widget _placeCard(Map<String, dynamic> p, bool isDark) {
    final k = _kindOf(p);
    final (color, icon, label) = _style(k);
    final count = _priceCount(p, k);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(tr(p['name']?.toString() ?? ''),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(
            k == _Kind.other ? label : '$label • ${trf('{0} نرخ', [PlaceDisplay.digits(count)])}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () async {
            HapticFeedback.selectionClick();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Directionality(
                  textDirection: AppLang.direction,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(tr(p['name']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w900)),
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                    ),
                    body: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_dashboard(p)],
                    ),
                  ),
                ),
              ),
            );
            if (mounted) _load();
          },
        ),
      ),
    );
  }

  Widget _note(bool isDark, IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );

  /// هەواڵ و ئەوانی تر — پانێڵی بەڕێوەبردنی پێشوو
  Widget _moreTile(bool isDark) => Material(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.dashboard_customize_rounded, color: AppColors.toneSlate),
          title: Text(tr('بەڕێوەبردنی زیاتر'), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(tr('هەموو ئامرازەکانی بەڕێوەبردن')),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          ),
        ),
      );
}

/// 📈 چارتی نرخەکانی یەک شوێن
class _VendorChartScreen extends StatelessWidget {
  const _VendorChartScreen({required this.title, required this.load, required this.isCurrency});

  final String title;
  final Future<List<Map<String, dynamic>>> Function() load;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF2F5FA),
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final history = snap.data ?? const [];
            if (history.isEmpty) {
              return Center(
                child: Text(
                  tr('هێشتا هیچ مێژوویەکی نرخ نییە'),
                  style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                isCurrency
                    ? MultiCurrencyChartWidget(history: history, isDark: isDark)
                    : MultiFuelChartWidget(history: history, isDark: isDark),
              ],
            );
          },
        ),
      ),
    );
  }
}
