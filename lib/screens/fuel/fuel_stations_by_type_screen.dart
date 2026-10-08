import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/settings_provider.dart';
import '../../services/fuel_service.dart';
import '../../services/auth_service.dart';
import '../admin/admin_fuel_prices.dart';

/// 🏢 لیستی بەنزینخانەکان بەپێی جۆر — بینین بۆ کڕیار، دەستکاری بۆ ئەدمین/ڤێندەر
class FuelStationsByTypeScreen extends StatefulWidget {
  final String fuelType;

  const FuelStationsByTypeScreen({super.key, required this.fuelType});

  @override
  State<FuelStationsByTypeScreen> createState() =>
      _FuelStationsByTypeScreenState();
}

class _FuelStationsByTypeScreenState extends State<FuelStationsByTypeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stations = [];

  // ✅ پشکنینی دەستکاریکردن
  bool get _canEdit {
    final role = AuthSessionManager.userRole;
    return role == 'admin' || role == 'vendor';
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    try {
      final stations = await FuelService.getCurrentPrices(
        fuelType: widget.fuelType,
      );

      if (mounted) {
        setState(() {
          _stations = stations;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final typeName = FuelService.getNameByLang(widget.fuelType, lang);
    final color = _hexToColor(FuelService.getColorForType(widget.fuelType));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            'بەنزینخانەکانی $typeName',
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
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadStations,
            ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: color))
            : _stations.isEmpty
            ? _buildEmptyState(isDark, typeName)
            : RefreshIndicator(
          color: color,
          onRefresh: _loadStations,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _stations.length,
            itemBuilder: (context, index) => _buildStationCard(
              _stations[index],
              index,
              isDark,
              color,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی بەنزینخانە
  // ═══════════════════════════════════════════════════════════
  Widget _buildStationCard(
      Map<String, dynamic> station,
      int index,
      bool isDark,
      Color color,
      ) {
    final name = station['station_name']?.toString() ?? 'بەنزینخانە';
    final address = station['station_address']?.toString() ?? '';
    final logo = station['station_logo']?.toString() ?? '';
    final image = station['station_image']?.toString() ?? '';
    final phone = station['station_phone']?.toString() ?? '';
    final price = (station['price'] as num?)?.toDouble() ?? 0;
    final isCheapest = index == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheapest
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : color.withValues(alpha: 0.2),
          width: isCheapest ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCheapest ? const Color(0xFF10B981) : color)
                .withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (isCheapest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'هەرزانترین',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isCheapest) const SizedBox(width: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (image.isNotEmpty || logo.isNotEmpty)
                    ? Image.network(
                  image.isNotEmpty ? image : logo,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _buildDefaultIcon(color),
                )
                    : _buildDefaultIcon(color),
              ),
              const SizedBox(width: 12),

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
                        color:
                        isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'د.ع / لیتر',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════
          // ✅ دوگمەکان — تەنها پەیوەندی بۆ یوزەر
          // دەستکاری تەنها بۆ ئەدمین / ڤێندەر
          // ═══════════════════════════════════════════════════
          if (phone.isNotEmpty || _canEdit) ...[
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // 📞 دوگمەی پەیوەندی — هەمیشە بۆ هەمووان
                if (phone.isNotEmpty)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.call_rounded,
                      label: 'پەیوەندی',
                      color: Colors.green,
                      onTap: () async {
                        final Uri uri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                  ),

                // 🚫 هەندێک جیاکەرەوە
                if (phone.isNotEmpty && _canEdit)
                  const SizedBox(width: 8),

                // ✏️ دوگمەی نوێکردنەوەی نرخ — تەنها بۆ ئەدمین/ڤێندەر
                if (_canEdit)
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit_rounded,
                      label: 'نوێکردنەوەی نرخ',
                      color: color,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminFuelPricesScreen(
                              station: {
                                'id': station['station_id'],
                                'name': name,
                                'address': address,
                              },
                            ),
                          ),
                        );
                        if (result == true) _loadStations();
                      },
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(Color color) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.local_gas_station_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String typeName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_gas_station_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ بەنزینخانەیەک نییە بۆ $typeName',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFFFD700);
    }
  }
}