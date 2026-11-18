// lib/widgets/neighborhoods/neighborhood_alerts_card.dart
//
// 📍 لە شاشەی گەڕەکدا: دوگمەی «ئاگاداریی ئەم گەڕەکەم بۆ بنێرە» و دوایین ئاگادارییەکان.

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/neighborhood_alert_service.dart';

class NeighborhoodAlertsCard extends StatefulWidget {
  final int neighborhoodId;
  final Color color;

  /// بۆ تێست؛ ئەگەر نەدرا لە Supabase دەهێنرێت
  final Future<List<NeighborhoodAlert>> Function(int neighborhoodId)? loader;

  const NeighborhoodAlertsCard({
    super.key,
    required this.neighborhoodId,
    required this.color,
    this.loader,
  });

  @override
  State<NeighborhoodAlertsCard> createState() => _NeighborhoodAlertsCardState();
}

class _NeighborhoodAlertsCardState extends State<NeighborhoodAlertsCard> {
  bool _on = false;
  bool _busy = false;
  List<NeighborhoodAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final subscribed = await NeighborhoodAlertService.subscribed();
    if (mounted) setState(() => _on = subscribed.contains(widget.neighborhoodId));
    try {
      final alerts = await (widget.loader ??
          (id) => NeighborhoodAlertService.recent(id))(widget.neighborhoodId);
      if (mounted) setState(() => _alerts = alerts);
    } catch (e) {
      debugPrint('⚠️ neighborhood alerts: $e');
    }
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      await NeighborhoodAlertService.setSubscribed(widget.neighborhoodId, on);
      if (mounted) setState(() => _on = on);
    } catch (e) {
      debugPrint('⚠️ neighborhood topic: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(tr('نەتوانرا، دووبارە هەوڵ بدەرەوە')),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = isDark ? Colors.white60 : Colors.grey.shade600;
    final color = widget.color;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('ئاگاداریی ئەم گەڕەکەم بۆ بنێرە'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
                    Text(tr('بڕینی ئاو، کارەبا و ئاگادارییە گرنگەکان'),
                        style: TextStyle(fontSize: 11.5, color: sub)),
                  ],
                ),
              ),
              _busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Switch(
                      key: const ValueKey('nbh-alerts-switch'),
                      value: _on,
                      activeThumbColor: color,
                      onChanged: _toggle,
                    ),
            ],
          ),
          if (_alerts.isNotEmpty) ...[
            const Divider(height: 18),
            Text(tr('دوایین ئاگادارییەکان'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
            for (final a in _alerts.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
                          if (a.body.isNotEmpty)
                            Text(a.body, style: TextStyle(fontSize: 12.5, color: sub, height: 1.5)),
                        ],
                      ),
                    ),
                    if (a.createdAt != null)
                      Text(
                        AppLang.localDigits('${a.createdAt!.day}/${a.createdAt!.month}', AppLang.code),
                        style: TextStyle(fontSize: 11.5, color: sub),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
