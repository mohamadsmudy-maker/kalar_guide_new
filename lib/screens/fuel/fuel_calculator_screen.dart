import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/fuel_service.dart';

/// 🧮 حسابکەری نرخ
class FuelCalculatorScreen extends StatefulWidget {
  const FuelCalculatorScreen({super.key});

  @override
  State<FuelCalculatorScreen> createState() => _FuelCalculatorScreenState();
}

class _FuelCalculatorScreenState extends State<FuelCalculatorScreen> {
  final _litersCtrl = TextEditingController(text: '10');
  String? _selectedType;
  double _pricePerLiter = 0;
  double _total = 0;

  List<Map<String, String>> _fuelTypes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrices();
    _litersCtrl.addListener(_calculate);
  }

  @override
  void dispose() {
    _litersCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrices() async {
    try {
      _fuelTypes = FuelService.getFuelTypesForLang('ku');
      if (_fuelTypes.isNotEmpty) {
        _selectedType = _fuelTypes[0]['key'];
        await _updatePrice();
      }
    } catch (e) {
      debugPrint('❌ Load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updatePrice() async {
    if (_selectedType == null) return;

    try {
      final prices = await FuelService.getCurrentPrices(
        fuelType: _selectedType,
      );

      final validPrices = prices
          .map((p) => (p['price'] as num?)?.toDouble() ?? 0)
          .where((p) => p > 0)
          .toList();

      if (validPrices.isNotEmpty) {
        _pricePerLiter =
            validPrices.reduce((a, b) => a < b ? a : b);
      } else {
        _pricePerLiter = 0;
      }

      _calculate();
    } catch (e) {
      debugPrint('❌ Update price error: $e');
    }
  }

  void _calculate() {
    final liters = double.tryParse(_litersCtrl.text) ?? 0;
    setState(() {
      _total = liters * _pricePerLiter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: const Text(
            '🧮 حسابکەری نرخ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ⭐ Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1B2E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFD700)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? const Color(0xFF1A1B2E)
                        : Colors.white,
                    style: TextStyle(
                      color:
                      isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    items: _fuelTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type['key'],
                        child: Text(type['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) async {
                      setState(() => _selectedType = v);
                      await _updatePrice();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ⭐ نرخی لیتر
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1B2E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD700)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.attach_money_rounded,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'نرخی هەر لیتر',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _pricePerLiter > 0
                          ? '${_pricePerLiter.toStringAsFixed(0)} د.ع'
                          : '-- د.ع',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ⭐ لیتر
              TextField(
                controller: _litersCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  labelText: 'چەند لیتر؟',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFD700),
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Color(0xFFFFD700),
                  ),
                  suffixText: 'لیتر',
                ),
              ),
              const SizedBox(height: 20),

              // ⭐ Total
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFB300),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF0F1421),
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'کۆی گشتی',
                      style: TextStyle(
                        color: Color(0xFF0F1421),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _total.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Color(0xFF0F1421),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'دیناری عێراقی',
                      style: TextStyle(
                        color: Color(0xFF0F1421),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}