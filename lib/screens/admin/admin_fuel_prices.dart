import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/fuel_service.dart';
import '../fuel/fuel_history_screen.dart';

/// 💰 نوێکردنەوەی نرخی بەنزینخانە + مێژوو
class AdminFuelPricesScreen extends StatefulWidget {
  final Map<String, dynamic> station;

  const AdminFuelPricesScreen({super.key, required this.station});

  @override
  State<AdminFuelPricesScreen> createState() => _AdminFuelPricesScreenState();
}

class _AdminFuelPricesScreenState extends State<AdminFuelPricesScreen> {
  bool _loading = true;
  Map<String, dynamic> _fuelPrices = {};

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  void _loadPrices() {
    final prices = widget.station['fuel_prices'];

    setState(() {
      _fuelPrices = prices is Map
          ? Map<String, dynamic>.from(prices)
          : <String, dynamic>{};
      _loading = false;
    });
  }

  void _openHistory(String? fuelType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FuelHistoryScreen(
          stationId: widget.station['id'],
          stationName: widget.station['name']?.toString() ?? 'بەنزینخانە',
          fuelType: fuelType,
        ),
      ),
    );
  }

  Future<void> _updatePrice(String fuelType) async {
    final currentPrice = (_fuelPrices[fuelType] as num?)?.toDouble() ?? 0;

    final priceCtrl = TextEditingController(
      text: currentPrice.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFFB8860B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'نوێکردنەوەی نرخ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      FuelService.getNameKu(fuelType),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'نرخی ئێستا: ${currentPrice.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'نرخی نوێ (د.ع)',
                    prefixIcon: const Icon(
                      Icons.attach_money_rounded,
                      color: Color(0xFFFFD700),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFD700),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'تێبینی (ئارەزوومەندانە)',
                    hintText: 'بۆ نموونە: بەهۆی گۆڕانی نرخی نەوت',
                    prefixIcon: const Icon(
                      Icons.note_rounded,
                      color: Color(0xFFFFD700),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFD700),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('پاشگەزبوونەوە'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF0F1421),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final newPrice = double.tryParse(priceCtrl.text);
                if (newPrice == null || newPrice < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('تکایە نرخێکی دروست بنووسە'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final success = await FuelService.updatePrice(
                  stationId: widget.station['id'],
                  fuelType: fuelType,
                  newPrice: newPrice,
                  updatedByName: AuthSessionManager.userName ?? 'بەکارهێنەر',
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                );

                if (ctx.mounted && success) {
                  Navigator.pop(ctx, true);
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'پاشەکەوتکردن',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final updated = await FuelService.getStationPrices(
        widget.station['id'],
      );

      if (updated != null && mounted) {
        setState(() {
          _fuelPrices = updated['fuel_prices'] is Map
              ? Map<String, dynamic>.from(updated['fuel_prices'] as Map)
              : {};
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ نرخ نوێکرایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.station['name']?.toString() ?? 'بەنزینخانە';
    final address = widget.station['address']?.toString() ?? '';

    // ✅ بەکارهێنانی هەمان جۆرەکانی FuelService
    const fuelTypes = FuelService.fuelTypes;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            name,
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
              icon: const Icon(Icons.history_rounded),
              tooltip: 'مێژووی هەموو نرخەکان',
              onPressed: () => _openHistory(null),
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ هێدەری بەنزینخانە — وەک FuelTypesScreen
            _buildStationHeader(name, address),
            const SizedBox(height: 20),

            // ✅ ناونیشانی بەش
            _buildSectionTitle('جۆرەکانی سووتەمەنی'),
            const SizedBox(height: 12),

            // ✅ کارتەکان بە هەمان شێوازی FuelTypesScreen
            ...fuelTypes.map((type) => _buildPriceCard(type, isDark)),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 هێدەری بەنزینخانە — وەک سووتەمەنی
  // ═══════════════════════════════════════════════════════════
  Widget _buildStationHeader(String name, String address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1B2E), Color(0xFF2D1B4E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              color: Color(0xFF0F1421),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFFFD700),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
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
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 ناونیشانی بەش
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی نرخ — ✅ بە هەمان شێوازی FuelTypesScreen
  // ═══════════════════════════════════════════════════════════
  Widget _buildPriceCard(Map<String, dynamic> type, bool isDark) {
    final fuelType = type['key'] as String;
    final nameKu = type['name_ku'] as String;
    final color = _hexToColor(type['color'] as String);

    final price = (_fuelPrices[fuelType] as num?)?.toDouble() ?? 0;
    final hasPrice = price > 0;

    return GestureDetector(
      onTap: () => _updatePrice(fuelType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // 🎨 ئایکۆن — وەک سووتەمەنی
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // 📝 ناوی جۆر
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nameKu,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 11,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'کلیک بکە بۆ دەستکاری',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 💰 نرخ — وەک سووتەمەنی
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
                          colors: hasPrice
                              ? [color, color.withValues(alpha: 0.8)]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        hasPrice ? price.toStringAsFixed(0) : '--',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'د.ع / لیتر',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ✅ دوگمەی مێژوو
            if (hasPrice) ...[
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openHistory(fuelType),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: color,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'بینینی مێژووی گۆڕانکاری',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: color,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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