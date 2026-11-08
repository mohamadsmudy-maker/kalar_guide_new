import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';
import '../../widgets/multi_fuel_chart_widget.dart';
import 'admin_fuel_prices.dart';
import '../../l10n/tr.dart';

/// 🏢 شاشەی بەڕێوەبردنی بەنزینخانەکان — FULL PRO (Admin)
class AdminFuelStationsScreen extends StatefulWidget {
  const AdminFuelStationsScreen({super.key});

  @override
  State<AdminFuelStationsScreen> createState() =>
      _AdminFuelStationsScreenState();
}

class _AdminFuelStationsScreenState extends State<AdminFuelStationsScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _allHistory = [];
  String _searchQuery = '';
  String _filterType = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;

      List<Map<String, dynamic>> stations;
      if (role == 'vendor' && user != null) {
        final phone = user['phone']?.toString() ?? '';
        stations = await FuelService.getVendorStations(phone);
      } else {
        stations = await FuelService.getAllStations();
      }

      final history = await FuelService.getMonthlyHistory(monthsBack: 6);

      if (mounted) {
        setState(() {
          _stations = stations;
          _allHistory = history;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStations {
    var list = _stations;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final address = (s['address'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || address.contains(q) || phone.contains(q);
      }).toList();
    }

    if (_filterType != 'all') {
      list = list.where((s) {
        final prices = s['fuel_prices'];
        if (prices is! Map) return false;
        return prices[_filterType] != null;
      }).toList();
    }

    return list;
  }

  // ✅ PDF
  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      await FuelPdfService.generateDateRangeReport(
        context: context,
        fromDate: DateTime.now().subtract(const Duration(days: 30)),
        toDate: DateTime.now(),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final role = AuthSessionManager.userRole;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            tr(role == 'vendor' ? 'بەنزینخانەکەم' : 'بەڕێوەبردنی سووتەمەنی'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            // ✅ دوگمەی PDF
            IconButton(
              icon: _generatingPdf
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFD700),
                ),
              )
                  : const Icon(Icons.picture_as_pdf_rounded),
              tooltip: tr('ڕاپۆرتی PDF'),
              onPressed: _generatingPdf ? null : _generatePdf,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadAllData,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        )
            : RefreshIndicator(
          color: const Color(0xFFFFD700),
          onRefresh: _loadAllData,
          child: CustomScrollView(
            slivers: [
              // ═══════════════════════════════════════
              // 📊 Chart ی گشتی
              // ═══════════════════════════════════════
              if (_allHistory.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: MultiFuelChartWidget(
                      history: _allHistory,
                      isDark: isDark,
                    ),
                  ),
                ),

              // ═══════════════════════════════════════
              // 🔍 گەڕان
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildSearchBar(isDark),
                ),
              ),

              // ═══════════════════════════════════════
              // 🏷️ فلتەر
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildTypeFilter(isDark),
                ),
              ),

              // ═══════════════════════════════════════
              // 📋 ئاماری ئەنجام
              // ═══════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildResultCount(isDark),
                ),
              ),

              // ═══════════════════════════════════════
              // 🏢 لیستی بەنزینخانەکان
              // ═══════════════════════════════════════
              if (_filteredStations.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_gas_station_rounded,
                          size: 80,
                          color: isDark
                              ? Colors.white24
                              : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('هیچ بەنزینخانەیەک نەدۆزرایەوە'),
                          style: TextStyle(
                            color:
                            isDark ? Colors.white54 : Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildStationCard(
                        _filteredStations[index],
                        isDark,
                        lang,
                      ),
                      childCount: _filteredStations.length,
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
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: tr('گەڕان بەدوای بەنزینخانەکان...'),
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFFFD700),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Type Filter
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeFilter(bool isDark) {
    final types = [
      {'key': 'all', 'label': 'هەموو', 'color': Colors.grey},
      {'key': 'normal', 'label': 'ئاسایی', 'color': const Color(0xFF1E88E5)},
      {'key': 'super', 'label': 'سوپەر', 'color': const Color(0xFFEF4444)},
      {'key': 'muhassen', 'label': 'محەسەن', 'color': const Color(0xFFF59E0B)},
      {'key': 'oil', 'label': 'زەیت', 'color': const Color(0xFF14B8A6)},
      {'key': 'iraqi_gas', 'label': 'گازی عێراقی', 'color': const Color(0xFF10B981)},
      {'key': 'iranian_gas', 'label': 'گازی ئێرانی', 'color': const Color(0xFF8B5CF6)},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = _filterType == type['key'];
          final color = type['color'] as Color;

          return GestureDetector(
            onTap: () => setState(() => _filterType = type['key'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? const Color(0xFF1A1B2E) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  tr(type['label'] as String),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Result Count
  // ═══════════════════════════════════════════════════════════
  Widget _buildResultCount(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: Color(0xFFFFB300),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                trf('{0} بەنزینخانە', [_filteredStations.length]),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8860B),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (_filterType != 'all' || _searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() {
                _filterType = 'all';
                _searchQuery = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt_off_rounded,
                    size: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tr('لابردنی فلتەر'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Station Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildStationCard(
      Map<String, dynamic> station,
      bool isDark,
      String lang,
      ) {
    final name = station['name']?.toString() ?? 'بەنزینخانە';
    final address = station['address']?.toString();
    final isVerified = station['is_verified'] == true;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminFuelPricesScreen(station: station),
          ),
        );
        if (result == true) _loadAllData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isVerified
                ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade200),
            width: isVerified ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.local_gas_station_rounded,
                      color: Color(0xFF0F1421),
                      size: 28,
                    ),
                  ),
                  if (isVerified)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF1E88E5),
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(name),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color:
                      isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color:
                          isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tr(address),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFFFD700),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}