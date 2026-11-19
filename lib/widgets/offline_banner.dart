// lib/widgets/offline_banner.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// 📡 شریتێکی بچووک لە سەرەوە کاتێک ئینتەرنێت نییە:
/// «بێ ئینتەرنێت — زانیارییە هەڵگیراوەکان پیشان دەدرێن».
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child, this.onlineStream});

  final Widget child;

  /// true = ئینتەرنێت هەیە. بۆ تاقیکردنەوە؛ ئەگینا connectivity_plus
  final Stream<bool>? onlineStream;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _online = true;
  StreamSubscription<bool>? _sub;

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    final stream = widget.onlineStream;
    if (stream != null) {
      _sub = stream.listen(_set);
      return;
    }
    try {
      final c = Connectivity();
      c.checkConnectivity().then((r) => _set(_isOnline(r))).catchError((_) {});
      _sub = c.onConnectivityChanged.map(_isOnline).listen(_set, onError: (_) {});
    } catch (_) {
      // پلاتفۆرمی بێ connectivity (تاقیکردنەوە): وا دابنێ ئینتەرنێت هەیە
    }
  }

  void _set(bool online) {
    if (mounted && online != _online) setState(() => _online = online);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return widget.child;
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Material(
          key: const ValueKey('offline-banner'),
          color: const Color(0xFF374151),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, top + 4, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tr('بێ ئینتەرنێت — زانیارییە هەڵگیراوەکان پیشان دەدرێن'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.child),
        ),
      ],
    );
  }
}
