// lib/screens/admin/featured_place_sheet.dart
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/featured_places.dart';
import '../../widgets/featured_badge.dart';

/// ⭐ ئەدمین: شوێنێک بۆ ماوەیەک پێشنیارکراو بکە، یان لای ببە.
/// دەگەڕێتەوە: true = گۆڕا. [save] بۆ تاقیکردنەوە.
Future<bool> showFeaturedPlaceSheet(
  BuildContext context,
  Map<String, dynamic> place, {
  Future<DateTime?> Function(Object id, int? days)? save,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => FeaturedPlaceSheet(place: place, save: save ?? FeaturedPlaces.setFeatured),
  );
  return changed == true;
}

class FeaturedPlaceSheet extends StatefulWidget {
  const FeaturedPlaceSheet({super.key, required this.place, required this.save});

  final Map<String, dynamic> place;
  final Future<DateTime?> Function(Object id, int? days) save;

  @override
  State<FeaturedPlaceSheet> createState() => _FeaturedPlaceSheetState();
}

class _FeaturedPlaceSheetState extends State<FeaturedPlaceSheet> {
  bool _saving = false;

  Future<void> _apply(int? days) async {
    setState(() => _saving = true);
    try {
      final until = await widget.save(widget.place['id'], days);
      widget.place['featured_until'] = until?.toIso8601String();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = FeaturedPlaces.isFeatured(widget.place, enabled: true);
    final until = FeaturedPlaces.until(widget.place)?.toLocal();
    final name = widget.place['name']?.toString() ?? '';
    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const FeaturedBadge(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              featured && until != null
                  ? trf('ئێستا پێشنیارکراوە تا {0}', [
                      AppLang.localDigits('${until.year}/${until.month}/${until.day}'),
                    ])
                  : tr('لە سەرەوەی لیست و گەڕان دەردەکەوێت لەگەڵ نیشانەی «پێشنیارکراو». کاتێک ماوەکە تەواو بوو، خۆکار دەگەڕێتەوە.'),
              style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.grey.shade700),
            ),
            if (!FeaturedPlaces.enabled) ...[
              const SizedBox(height: 8),
              Text(
                tr('⚠️ تایبەتمەندیی «شوێنی پێشنیارکراو» لە ناوەندی کۆنترۆڵ کوژاوەتەوە، بۆیە ئێستا بۆ بەکارهێنەران دەرناکەوێت.'),
                style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFFB45309)),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in FeaturedPlaces.durations)
                  FilledButton(
                    key: ValueKey('feature-$d'),
                    onPressed: _saving ? null : () => _apply(d),
                    style: FilledButton.styleFrom(backgroundColor: FeaturedBadge.gold),
                    child: Text(trf('{0} ڕۆژ', [AppLang.localDigits('$d')])),
                  ),
              ],
            ),
            if (featured) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('feature-remove'),
                onPressed: _saving ? null : () => _apply(null),
                icon: const Icon(Icons.star_border_rounded),
                label: Text(tr('لابردنی پێشنیارکراو')),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
