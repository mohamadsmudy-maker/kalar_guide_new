import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/fuel/fuel_strings.dart';
import '../services/currency_service.dart';
import '../services/fuel_service.dart';

/// 🧮 حیسابکەری تێچووی سووتەمەنی
///   • بەپێی بڕ: چەند لیتر ← چەند دینار
///   • بەپێی پارە: چەند دینار ← چەند لیتر
///   هەرزانترین نرخ بەکاردێت و پاشەکەوت لە بەرامبەر گرانترین نیشان دەدرێت
class FuelCostCalculatorCard extends StatefulWidget {
  final Map<String, FuelMarket> markets;
  final String lang;
  final bool isDark;

  const FuelCostCalculatorCard({
    super.key,
    required this.markets,
    required this.lang,
    required this.isDark,
  });

  @override
  State<FuelCostCalculatorCard> createState() => _FuelCostCalculatorCardState();
}

class _FuelCostCalculatorCardState extends State<FuelCostCalculatorCard> {
  final _ctrl = TextEditingController(text: '20');
  String? _type;
  bool _byAmount = true;

  String t(String k) => FuelStrings.of(widget.lang, k);
  String fmt(num? v, {int d = 0}) => CurrencyService.formatPrice(v, widget.lang, decimals: d);

  List<String> get _available => FuelService.fuelTypes
      .map((e) => e['key'] as String)
      .where((k) => widget.markets[k]?.hasData ?? false)
      .toList();

  double get _input {
    final raw = _ctrl.text.replaceAll(',', '').trim().replaceAllMapped(
          RegExp('[٠-٩]'),
          (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}',
        );
    return double.tryParse(raw) ?? 0;
  }

  void _setInput(num v) {
    _ctrl.text = v.toStringAsFixed(0);
    HapticFeedback.selectionClick();
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    if (available.isEmpty) return const SizedBox.shrink();

    final type = (_type != null && available.contains(_type)) ? _type! : available.first;
    final m = widget.markets[type]!;
    final color = CurrencyService.hexToColor(FuelService.getColorForType(type));
    final unit = FuelService.getUnitName(type, widget.lang);
    final gas = FuelService.isGas(type);
    final price = m.minPrice ?? 0;
    final maxPrice = m.maxPrice ?? price;

    final input = _input;
    final result = price <= 0 ? null : (_byAmount ? input * price : input / price);
    final saving = (_byAmount && maxPrice > price) ? input * (maxPrice - price) : null;

    final presets = _byAmount
        ? (gas ? [1, 2, 3, 5] : [10, 20, 40, 60])
        : [5000, 10000, 25000, 50000];

    final textColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final sub = widget.isDark ? Colors.white60 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('calculator'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
              ),
              _modeToggle(color),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: available.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final k = available[i];
                final sel = k == type;
                final c = CurrencyService.hexToColor(FuelService.getColorForType(k));
                return ChoiceChip(
                  label: Text('${FuelService.getEmoji(k)} ${FuelService.getNameByLang(k, widget.lang)}'),
                  selected: sel,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _type = k;
                      if (_byAmount) _ctrl.text = FuelService.isGas(k) ? '1' : '20';
                    });
                  },
                  selectedColor: c.withValues(alpha: 0.2),
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: sel ? c : sub),
                  side: BorderSide(color: sel ? c : Colors.transparent),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]'))],
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
            decoration: InputDecoration(
              labelText: _byAmount ? '${t('amount')} ($unit)' : t('budget'),
              prefixIcon: Icon(_byAmount ? Icons.local_gas_station_rounded : Icons.payments_rounded, color: color),
              filled: true,
              fillColor: widget.isDark ? Colors.black26 : Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: presets
                .map((p) => ActionChip(
                      label: Text(fmt(p)),
                      onPressed: () => _setInput(p),
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                      backgroundColor: color.withValues(alpha: 0.08),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_byAmount ? t('you_pay') : t('you_get'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _byAmount ? '${fmt(result)} ${t('iqd')}' : '${fmt(result, d: gas ? 0 : 1)} $unit',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${t('at')} ${m.cheapest?['station_name'] ?? ''} • ${fmt(price)} ${t('iqd')} / $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (saving != null && saving > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '💰 ${t('saving')}: ${fmt(saving)} ${t('iqd')}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeToggle(Color color) {
    Widget btn(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : color)),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(t('by_amount'), _byAmount, () => setState(() {
                _byAmount = true;
                _ctrl.text = '20';
              })),
          btn(t('by_budget'), !_byAmount, () => setState(() {
                _byAmount = false;
                _ctrl.text = '25000';
              })),
        ],
      ),
    );
  }
}
