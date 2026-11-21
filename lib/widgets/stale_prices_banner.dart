// lib/widgets/stale_prices_banner.dart
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/app_control.dart';
import '../services/currency_service.dart';
import '../services/fuel_service.dart';
import 'live_badge.dart';

/// ⚠️ بۆ ئەدمین: ئەگەر نرخی سووتەمەنی یان دراو لە ٢٤ سەعاتی ڕابردوودا نوێ
/// نەکرابێتەوە (و بەشەکە چالاک بێت) ئاگادار دەکاتەوە. نرخی کۆن متمانە دەشکێنێت.
class StalePricesBanner extends StatefulWidget {
  const StalePricesBanner({super.key, this.loader, this.now});

  /// بۆ تاقیکردنەوە: (سووتەمەنی، دراو)
  final Future<(DateTime?, DateTime?)> Function()? loader;
  final DateTime? now;

  static Future<(DateTime?, DateTime?)> _load() async {
    final r = await Future.wait<DateTime?>([
      FuelService.getMarketSnapshot(monthsBack: 1).then((s) => s.lastUpdated, onError: (_) => null),
      CurrencyService.getMarketSnapshot(monthsBack: 1).then((s) => s.lastUpdated, onError: (_) => null),
    ]);
    return (r[0], r[1]);
  }

  @override
  State<StalePricesBanner> createState() => _StalePricesBannerState();
}

class _StalePricesBannerState extends State<StalePricesBanner> {
  (DateTime?, DateTime?)? _data;

  @override
  void initState() {
    super.initState();
    (widget.loader ?? StalePricesBanner._load)().then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((_) {});
  }

  String? _line(String label, DateTime? at) {
    if (LiveBadge.isFresh(at, now: widget.now)) return null;
    if (at == null) return trf('{0}: هیچ نرخێک تۆمار نەکراوە', [tr(label)]);
    final days = (widget.now ?? DateTime.now()).difference(at.toLocal()).inDays;
    return days < 1
        ? trf('{0}: زیاتر لە ٢٤ سەعاتە نوێ نەکراوەتەوە', [tr(label)])
        : trf('{0}: {1} ڕۆژە نوێ نەکراوەتەوە', [tr(label), days]);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final control = AppControl.state.value;
    final lines = [
      if (control.feature('fuel_prices')) _line('نرخی سووتەمەنی', d.$1),
      if (control.feature('currency_prices')) _line('نرخی دراو', d.$2),
    ].whereType<String>().toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('stale-prices'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5D28B)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.schedule_rounded, color: Color(0xFFB45309)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('نرخەکان کۆنن'),
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
            const SizedBox(height: 4),
            for (final l in lines)
              Text('• $l', style: const TextStyle(fontSize: 12.5, height: 1.6, color: Color(0xFF92400E))),
            const SizedBox(height: 4),
            Text(tr('نوێیان بکەرەوە یان بەشەکە لە ناوەندی کۆنترۆڵ بکوژێنەرەوە.'),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309))),
          ]),
        ),
      ]),
    );
  }
}
