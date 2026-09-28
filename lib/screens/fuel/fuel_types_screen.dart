import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/fuel_price.dart';
import '../../models/fuel_price_history.dart';
import '../../services/fuel_service.dart';
import 'fuel_prices_screen.dart';

/// 🛢️ شاشەی جۆرەکانی سووتەمەنی — هەرزانترین نرخەکان
class FuelTypesScreen extends StatefulWidget {
  const FuelTypesScreen({super.key});

  @override
  State<FuelTypesScreen> createState() => _FuelTypesScreenState();
}

class _FuelTypesScreenState extends State<FuelTypesScreen> {
  bool _loading = true;
  List<FuelPrice> _fuelTypes = [];
  final Map<String, FuelPriceHistory> _cheapest = {};

  // 🎨 ناوی کوردی fallback (ئەگەر DB ناوی کوردی نەبوو)
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // ١. جۆرەکانی سووتەمەنی
      final typesRes = await Supabase.instance.client
          .from('fuel_prices')
          .select()
          .order('display_order');

      final types = (typesRes as List)
          .map((e) => FuelPrice.fromJson(e as Map<String, dynamic>))
          .toList();

      // ٢. هەموو نرخەکانی ئێستا (sorted by price ascending)
      final allPrices = await FuelService.getCurrentPrices();

      // ٣. هەرزانترین بۆ هەر جۆرێک
      final Map<String, FuelPriceHistory> cheapest = {};
      for (final p in allPrices) {
        final current = cheapest[p.fuelType];
        if (current == null || p.price < current.price) {
          cheapest[p.fuelType] = p;
        }
      }

      if (mounted) {
        setState(() {
          _fuelTypes = types;
          _cheapest
            ..clear()
            ..addAll(cheapest);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ FuelTypes error: $e');
      if (mounted) setState(() => _loading = false);
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
          backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_fuelTypes.isEmpty)
                _buildEmptyState(isDark)
              else
                ..._fuelTypes.map(
                      (type) => _buildTypeCard(type, isDark, lang),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎨 هێدەر
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هەرزانترین نرخەکان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'کرتە لە هەر جۆرێک بکە بۆ بینینی وێستگەکان لە هەرزان بۆ گران',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎴 کارتی جۆری سووتەمەنی
  // ═══════════════════════════════════════════════════════
  Widget _buildTypeCard(FuelPrice type, bool isDark, String lang) {
    final cheapest = _cheapest[type.fuelType];
    final color = _hexToColor(type.color);
    final typeName = _localizedName(type, lang);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FuelPricesScreen(initialFuelType: type.fuelType),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
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
            // 🎨 ئایکۆن
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(
                _getIconData(type.icon),
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // 📝 ناو + هەرزانترین بەنزینخانە
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (cheapest != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFF10B981),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cheapest.getStationName(lang),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'هیچ نرخێک نییە',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),

            // 💰 نرخ
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cheapest != null
                      ? '${cheapest.price.toStringAsFixed(0)}'
                      : '--',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  'د.ع / ${type.unit}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_left_rounded,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.local_gas_station_outlined,
              size: 70,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'هیچ جۆرێکی سووتەمەنی نییە',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════
  String _localizedName(FuelPrice type, String lang) {
    // یەکەم: لە DB
    final dbName = type.getName(lang);
    if (dbName.isNotEmpty &&
        dbName.toLowerCase() != type.fuelType.toLowerCase()) {
      return dbName;
    }
    // دووەم: fallback
    return _fallbackNames[type.fuelType]?[lang] ?? type.fuelType;
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