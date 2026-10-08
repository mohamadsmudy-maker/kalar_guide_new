import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../admin/admin_fuel_prices.dart';

/// 🏢 شاشەی لیستی بەنزینخانەکان (بۆ ئەدمین + ڤێندەر)
class AdminFuelStationsScreen extends StatefulWidget {
  const AdminFuelStationsScreen({super.key});

  @override
  State<AdminFuelStationsScreen> createState() =>
      _AdminFuelStationsScreenState();
}

class _AdminFuelStationsScreenState extends State<AdminFuelStationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stations = []; // ✅ گۆڕدرا بۆ Map
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    try {
      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;

      List<Map<String, dynamic>> stations; // ✅ Map

      if (role == 'vendor' && user != null) {
        // ✅ ڤێندەر — تەنها بەنزینخانەی خۆی
        final phone = user['phone']?.toString() ?? '';
        final res = await Supabase.instance.client
            .from('dukan') // ✅ دەبێت 'dukan' بێت نەک 'fuel_stations'
            .select()
            .eq('phone', phone)
            .eq('category', 'سوتەمەنی');
        stations = List<Map<String, dynamic>>.from(res);
      } else {
        // ✅ ئەدمین — هەموو بەنزینخانەکان
        stations = await FuelService.getAllStations();
      }

      if (mounted) {
        setState(() {
          _stations = stations;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStations {
    if (_searchQuery.isEmpty) return _stations;
    final q = _searchQuery.toLowerCase();
    return _stations.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || address.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final role = AuthSessionManager.userRole;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            role == 'vendor'
                ? 'بەنزینخانەکەم'
                : 'بەنزینخانەکان (${_stations.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadStations,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFD700),
          ),
        )
            : Column(
          children: [
            // 🔍 گەڕان
            if (role != 'vendor')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1B2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'گەڕان بەدوای بەنزینخانەکان...',
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
                        icon: Icon(
                          Icons.close,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey,
                        ),
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
                ),
              ),

            // 📋 لیست
            Expanded(
              child: _filteredStations.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                color: const Color(0xFFFFD700),
                onRefresh: _loadStations,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredStations.length,
                  itemBuilder: (context, index) =>
                      _buildStationCard(
                        _filteredStations[index],
                        isDark,
                        lang,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationCard(
      Map<String, dynamic> station, bool isDark, String lang) {
    // ✅ دەرهێنانی زانیاری لە Map
    final name = station['name']?.toString() ?? 'بەنزینخانە';
    final address = station['address']?.toString();
    final isVerified = station['is_verified'] == true;

    return GestureDetector(
      onTap: () async {
        // ✅ چوونە ناو شاشەی نرخ — station هەر Mapـە
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminFuelPricesScreen(station: station),
          ),
        );
        if (result == true) _loadStations();
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
            // 🏢 ئایکۆن
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

            // 📝 زانیاری
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
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
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
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

            // ➡️ ئایکۆن
            const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFFFD700),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_gas_station_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ بەنزینخانەیەک نەدۆزرایەوە',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}