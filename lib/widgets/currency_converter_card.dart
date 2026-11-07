import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/currency/currency_strings.dart';
import '../services/currency_service.dart';

/// 🔄 گۆڕینەوەی خێرای دراو بە باشترین نرخی بازاڕ
///   «دەکڕم»  → هەرزانترین نرخی فرۆشتنی نوسینگەکان بەکاردێت
///   «دەفرۆشم» → بەرزترین نرخی کڕینی نوسینگەکان بەکاردێت
class CurrencyConverterCard extends StatefulWidget {
  final Map<String, CurrencyMarket> markets;
  final String lang;
  final bool isDark;

  const CurrencyConverterCard({
    super.key,
    required this.markets,
    required this.lang,
    required this.isDark,
  });

  @override
  State<CurrencyConverterCard> createState() => _CurrencyConverterCardState();
}

class _CurrencyConverterCardState extends State<CurrencyConverterCard> {
  final _amountCtrl = TextEditingController(text: '100');
  String? _type;
  bool _iBuy = true;

  String t(String k) => CurrencyStrings.of(widget.lang, k);

  List<String> get _available => CurrencyService.currencyTypes
      .map((e) => e['key'] as String)
      .where((k) => k != 'iqd' && (widget.markets[k]?.hasData ?? false))
      .toList();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount {
    final raw = _amountCtrl.text.replaceAll(',', '').trim();
    final western = raw.replaceAllMapped(
      RegExp('[٠-٩]'),
      (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}',
    );
    return double.tryParse(western) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    if (available.isEmpty) return const SizedBox.shrink();

    final type = (_type != null && available.contains(_type)) ? _type! : available.first;
    final market = widget.markets[type]!;
    final color = CurrencyService.hexToColor(CurrencyService.getColorForType(type));
    final per = CurrencyService.getQuoteUnit(type);

    final rate = _iBuy ? market.bestSellPrice : market.bestBuyPrice;
    final station = _iBuy ? market.bestSell : market.bestBuy;
    final result = (rate == null || rate <= 0) ? null : _amount * rate / per;

    final cardColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = widget.isDark ? Colors.white60 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('converter'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
              _modeToggle(color),
            ],
          ),
          const SizedBox(height: 14),

          // ── دراوەکان ──
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: available.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final k = available[i];
                final selected = k == type;
                final c = CurrencyService.hexToColor(CurrencyService.getColorForType(k));
                return ChoiceChip(
                  label: Text('${CurrencyService.getFlag(k)} ${CurrencyService.getSymbol(k)}'),
                  selected: selected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _type = k);
                  },
                  selectedColor: c.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: selected ? c : subColor,
                  ),
                  side: BorderSide(color: selected ? c : Colors.transparent),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── بڕ ──
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]'))],
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
            decoration: InputDecoration(
              labelText: '${t('amount')} (${CurrencyService.getUnitName(type, widget.lang)})',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(CurrencyService.getSymbol(type),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              ),
              filled: true,
              fillColor: widget.isDark ? Colors.black26 : Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          // ── ئەنجام ──
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: result == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: result.round().toString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t('copied')), behavior: SnackBarBehavior.floating),
                    );
                  },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _iBuy ? t('you_pay') : t('you_get'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${CurrencyService.formatPrice(result, widget.lang)} ${t('iqd')}',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (station != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${t('at')} ${station['station_name'] ?? ''} • '
                      '${CurrencyService.formatPrice(rate, widget.lang)} ${t('per')} '
                      '${CurrencyService.localizeDigits('$per', widget.lang)} '
                      '${CurrencyService.getUnitName(type, widget.lang)}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : color,
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(t('i_buy'), _iBuy, () => setState(() => _iBuy = true)),
          btn(t('i_sell'), !_iBuy, () => setState(() => _iBuy = false)),
        ],
      ),
    );
  }
}
