import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/fuel_price.dart';
import '../../models/fuel_price_history.dart';
import '../../services/fuel_service.dart';
import '../../services/fuel_pdf_service.dart';
import 'station_details_screen.dart';

/// 🛢️ شاشەی نرخی سووتەمەنی — PRO EDITION
class FuelPricesScreen extends StatefulWidget {
  /// ⭐ جۆری سەرەتایی (لە شاشەی جۆرەکانەوە)
  final String? initialFuelType;

  const FuelPricesScreen({super.key, this.initialFuelType});

  @override
  State<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends State<FuelPricesScreen> {
  late String _selectedFuelType;
  List<FuelPrice> _fuelTypes = [];
  bool _loadingTypes = true;

  /// 🎨 ناوی کوردی fallback
  static const Map<String, Map<String, String>> _fallbackNames = {
    'super': {'ku': 'سوپەر', 'ar': 'سوبر', 'en': 'Super'},
    'muhassen': {'ku': 'محەسەن', 'ar': 'محسن', 'en': 'Muhassen'},
    'normal': {'ku': 'ئاسایی', 'ar': 'عادي', 'en': 'Normal'},
    'oil': {'ku': 'زەیت', 'ar': 'زيت', 'en': 'Oil'},
    'iraqi_gas': {
      'ku': 'گازی عێراقی',
      'ar': 'غاز عراقي',
      'en': 'Iraqi Gas'
    },
    'iranian_gas': {
      'ku': 'گازی ئێرانی',
      'ar': 'غاز إيراني',
      'en': 'Iranian Gas'
    },
    'gas': {'ku': 'گاز', 'ar': 'غاز', 'en': 'Gas'},
  };

  @override
  void initState() {
    super.initState();
    _selectedFuelType = widget.initialFuelType ?? 'normal';
    _loadFuelTypes();
  }

  Future<void> _loadFuelTypes() async {
    setState(() => _loadingTypes = true);
    try {
      final res = await Supabase.instance.client
          .from('fuel_prices')
          .select()
          .order('display_order');

      if (mounted) {
        setState(() {
          _fuelTypes = (res as List)
              .map((e) => FuelPrice.fromJson(e as Map<String, dynamic>))
              .toList();

          // ✅ ئەگەر initialFuelType نەبوو، یەکەم جۆر هەڵبژێرە
          if (widget.initialFuelType == null && _fuelTypes.isNotEmpty) {
            _selectedFuelType = _fuelTypes.first.fuelType;
          }
          _loadingTypes = false;
        });
      }
    } catch (e) {
      debugPrint('❌ FuelPrices error: $e');
      if (mounted) setState(() => _loadingTypes = false);
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
          title: const Text(
            'نرخی سووتەمەنی',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor:
          isDark ? const Color(0xFF1A1A22) : Colors.white,
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'ڕاپۆرتی PDF',
              onPressed: _loadingTypes ? null : () => _generatePdfReport(lang),
            ),
          ],
        ),
        body: _loadingTypes
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : Column(
          children: [
            // 🏷️ فلتەری جۆر
            _buildFuelTypeFilter(isDark, lang),
            const SizedBox(height: 8),

            // 📊 ژمارەی بەنزینخانەکان
            _buildResultInfo(isDark, lang),

            // 📋 لیستی بەنزینخانەکان (هەرزانترین لە سەرەوە)
            Expanded(
              child: FutureBuilder<List<FuelPriceHistory>>(
                key: ValueKey(_selectedFuelType), // ⭐ rebuild when type changes
                future: FuelService.getCurrentPrices(
                  fuelType: _selectedFuelType,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  final prices = snapshot.data!;

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => setState(() {}),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: prices.length,
                      itemBuilder: (context, index) => _buildStationCard(
                        prices[index],
                        index,
                        isDark,
                        lang,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🏷️ فلتەری جۆر
  // ═══════════════════════════════════════════════════
  Widget _buildFuelTypeFilter(bool isDark, String lang) {
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _fuelTypes.length,
        itemBuilder: (context, index) {
          final fuel = _fuelTypes[index];
          final isSelected = _selectedFuelType == fuel.fuelType;
          final color = _hexToColor(fuel.color);
          final displayName = _localizedName(fuel, lang);

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedFuelType = fuel.fuelType),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  )
                      : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconData(fuel.icon),
                      color: isSelected ? Colors.white : color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 📊 ئاماری ئەنجامەکان
  // ═══════════════════════════════════════════════════
  Widget _buildResultInfo(bool isDark, String lang) {
    return FutureBuilder<List<FuelPriceHistory>>(
      key: ValueKey('info_$_selectedFuelType'),
      future: FuelService.getCurrentPrices(fuelType: _selectedFuelType),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        final fuelTypeName =
            _fuelTypes
                .where((f) => f.fuelType == _selectedFuelType)
                .map((f) => _localizedName(f, lang))
                .firstOrNull ??
                _selectedFuelType;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_gas_station_rounded,
                color: AppColors.primary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '$count بەنزینخانە • $fuelTypeName',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (count > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.green,
                        size: 10,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'لە هەرزان بۆ گران',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // 🏢 کارتی بەنزینخانە
  // ═══════════════════════════════════════════════════
  Widget _buildStationCard(
      FuelPriceHistory price,
      int index,
      bool isDark,
      String lang,
      ) {
    final isCheapest = index == 0;
    final color = _hexToColor(FuelService.getColorForType(price.fuelType));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StationDetailsScreen(stationId: price.stationId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCheapest
                ? Colors.green.withValues(alpha: 0.5)
                : (isDark
                ? const Color(0xFF2A2A35)
                : Colors.grey.shade200),
            width: isCheapest ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCheapest
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 🥇 باجی هەرزانترین
            if (isCheapest)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'هەرزانترین',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 🏢 ئایکۆن
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.local_gas_station_rounded,
                            color: color,
                            size: 26,
                          ),
                        ),
                        if (price.isVerified == true)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.blue,
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
                      children: [
                        Text(
                          price.getStationName(lang),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (price.address != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  price.address!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        if (price.updatedAt != null)
                          Text(
                            _timeAgo(price.updatedAt!),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 💰 نرخ
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${price.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          'د.ع / ${price.unit}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color.withValues(alpha: 0.7),
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
    );
  }

  // ═══════════════════════════════════════════════════
  // 📄 ڕاپۆرتی PDF
  // ═══════════════════════════════════════════════════
  Future<void> _generatePdfReport(String lang) async {
    if (_fuelTypes.isEmpty) return;

    final selectedFuel = _fuelTypes.firstWhere(
          (f) => f.fuelType == _selectedFuelType,
      orElse: () => _fuelTypes.first,
    );

    await FuelPdfService.generateMonthlyReport(
      context: context,
      fuelTypeName: _localizedName(selectedFuel, lang),
      monthsBack: 3,
    );
  }

  // ═══════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════
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
            'هیچ نرخێک نییە بۆ ئەم جۆرە',
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

  String _localizedName(FuelPrice type, String lang) {
    final dbName = type.getName(lang);
    if (dbName.isNotEmpty &&
        dbName.toLowerCase() != type.fuelType.toLowerCase()) {
      return dbName;
    }
    return _fallbackNames[type.fuelType]?[lang] ?? type.fuelType;
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} دەقیقە لەمەوبەر';
    if (diff.inHours < 24) return '${diff.inHours} سەعات لەمەوبەر';
    if (diff.inDays < 30) return '${diff.inDays} ڕۆژ لەمەوبەر';
    return '${(diff.inDays / 30).floor()} مانگ لەمەوبەر';
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

  IconData _getIconData(String name) {
    switch (name) {
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'gas_meter':
        return Icons.gas_meter_rounded;
      case 'oil_barrel':
        return Icons.oil_barrel_rounded;
      case 'propane_tank':
        return Icons.propane_tank_rounded;
      default:
        return Icons.local_gas_station_rounded;
    }
  }
}