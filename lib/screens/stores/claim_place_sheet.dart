// lib/screens/stores/claim_place_sheet.dart
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/auth_service.dart';
import '../../services/place_claim_service.dart';

/// 🏪 «ئەم شوێنە هی منە؟» — داوا بۆ ئەدمین دەنێردرێت
class ClaimPlaceSheet extends StatefulWidget {
  const ClaimPlaceSheet({super.key, required this.storeId, required this.storeName, this.sender});

  final Object storeId;
  final String storeName;

  /// بۆ تاقیکردنەوە
  final Future<String> Function(Object storeId, String? note)? sender;

  static Future<void> show(BuildContext context, {required Object storeId, required String storeName}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ClaimPlaceSheet(storeId: storeId, storeName: storeName),
    );
  }

  @override
  State<ClaimPlaceSheet> createState() => _ClaimPlaceSheetState();
}

class _ClaimPlaceSheetState extends State<ClaimPlaceSheet> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    String r;
    try {
      final note = _note.text.trim().isEmpty ? null : _note.text.trim();
      r = await (widget.sender != null
          ? widget.sender!(widget.storeId, note)
          : PlaceClaimService.claim(widget.storeId, note: note));
    } catch (_) {
      r = 'error';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = switch (r) {
      'ok' => '✅ داواکارییەکەت نێردرا. دوای پشکنین ئاگادار دەکرێیتەوە.',
      'duplicate' => 'پێشتر داوات ناردووە، چاوەڕێی وەڵامی ئەدمین بە.',
      'already_owner' => 'تۆ پێشتر خاوەنی ئەم شوێنەیت.',
      'login' => 'سەرەتا بچۆ ژوورەوە.',
      _ => 'هەڵەیەک ڕوویدا',
    };
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg))));
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthSessionManager.isLoggedIn || widget.sender != null;
    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('ئەم شوێنە هی تۆیە؟'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              trf('ئەگەر خاوەن یان بەڕێوەبەری «{0}» ـیت، داوا بکە. دوای پەسەندکردنی ئەدمین دەتوانیت خۆت وێنە، کاتی کارکردن، ژمارە و نرخەکان نوێ بکەیتەوە.', [tr(widget.storeName)]),
              style: TextStyle(fontSize: 13, height: 1.6, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            if (!loggedIn)
              Text(tr('بۆ ناردنی داوا، سەرەتا لە پرۆفایل بچۆ ژوورەوە.'),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309)))
            else ...[
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr('تێبینی بۆ ئەدمین (ئیختیاری)'),
                  hintText: tr('بۆ نموونە: من خاوەنی ئەم دوکانەم، ژمارەی مۆبایلی دوکان...'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('claim-send'),
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified_user_rounded),
                label: Text(tr('ناردنی داوا')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
