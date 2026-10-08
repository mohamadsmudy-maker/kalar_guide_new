import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/fuel_service.dart';

/// 🏢 شاشەی وردەکاری بەنزینخانە
class StationDetailsScreen extends StatefulWidget {
  final int stationId;

  const StationDetailsScreen({super.key, required this.stationId});

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  // ✅ بە Map کار دەکەین نەک FuelStation
  Map<String, dynamic>? _station;
  Map<String, dynamic> _fuelPrices = {};
  bool _loadingStation = true;

  @override
  void initState() {
    super.initState();
    _loadStation();
  }

  Future<void> _loadStation() async {
    setState(() => _loadingStation = true);
    try {
      final station = await FuelService.getStationPrices(widget.stationId);

      if (mounted) {
        setState(() {
          _station = station;
          _fuelPrices = (station?['fuel_prices'] is Map)
              ? Map<String, dynamic>.from(station!['fuel_prices'] as Map)
              : <String, dynamic>{};
          _loadingStation = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _loadingStation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            _station?['name']?.toString() ?? 'بەنزینخانە',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: _loadingStation
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : _station == null
            ? const Center(
          child: Text(
            'بەنزینخانە نەدۆزرایەوە',
            style: TextStyle(color: Colors.grey),
          ),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🏢 کارتی بەنزینخانە
            _buildStationInfoCard(_station!, isDark, lang),
            const SizedBox(height: 16),

            // 💰 نرخەکانی ئێستا
            Text(
              'نرخەکانی ئێستا',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (_fuelPrices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'هیچ نرخێک نییە',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._fuelPrices.entries.map(
                    (entry) => _buildPriceTile(
                  entry.key,
                  (entry.value as num?)?.toDouble() ?? 0,
                  isDark,
                ),
              ),
            const SizedBox(height: 20),

            // 📊 دوگمەی نوێکردنەوەی نرخ
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _fuelPrices.isEmpty
                  ? null
                  : () => _showUpdatePriceDialog(isDark),
              icon: const Icon(Icons.edit_rounded),
              label: const Text(
                'نوێکردنەوەی نرخ',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),

            // 📜 مێژووی نرخەکان
            Text(
              'مێژووی نرخەکان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildHistoryList(isDark),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏢 کارتی زانیاری بەنزینخانە
  // ═══════════════════════════════════════════════════════════
  Widget _buildStationInfoCard(
      Map<String, dynamic> station, bool isDark, String lang) {
    final name = station['name']?.toString() ?? 'بەنزینخانە';
    final address = station['address']?.toString();
    final phone = station['phone']?.toString();
    final isVerified = station['is_verified'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isVerified)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'پارێزراو',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 کارتی نرخ
  // ═══════════════════════════════════════════════════════════
  Widget _buildPriceTile(String fuelType, double price, bool isDark) {
    final color = _hexToColor(FuelService.getColorForType(fuelType));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_gas_station_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              FuelService.getNameKu(fuelType),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            '${price.toStringAsFixed(0)} د.ع',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📜 مێژوو
  // ═══════════════════════════════════════════════════════════
  Widget _buildHistoryList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FuelService.getStationPriceHistory(
        stationId: widget.stationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'هیچ مێژوویەک نییە',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: history.take(20).map((item) {
            final fuelType = item['fuel_type']?.toString() ?? '';
            final price = (item['new_price'] as num?)?.toDouble() ?? 0;
            final createdAt = item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString())
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FuelService.getNameKu(fuelType),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${price.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 دیالۆگی نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════════════
  Future<void> _showUpdatePriceDialog(bool isDark) async {
    if (_fuelPrices.isEmpty) return;

    final fuelTypes = _fuelPrices.keys.toList();
    String selectedFuel = fuelTypes.first;
    final priceCtrl = TextEditingController(
      text: ((_fuelPrices[selectedFuel] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(0),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'نوێکردنەوەی نرخ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedFuel,
                  decoration: InputDecoration(
                    labelText: 'جۆری سووتەمەنی',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: fuelTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(FuelService.getNameKu(type)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setStateDialog(() {
                        selectedFuel = v;
                        priceCtrl.text =
                            ((_fuelPrices[v] as num?)?.toDouble() ?? 0)
                                .toStringAsFixed(0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نرخی نوێ (د.ع)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('پاشگەزبوونەوە'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final newPrice = double.tryParse(priceCtrl.text);
                  if (newPrice == null || newPrice < 0) return;

                  final success = await FuelService.updatePrice(
                    stationId: widget.stationId,
                    fuelType: selectedFuel,
                    newPrice: newPrice,
                    updatedByName: 'بەکارهێنەر',
                  );

                  if (ctx.mounted && success) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('نوێکردنەوە'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadStation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نرخ نوێکرایەوە ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}