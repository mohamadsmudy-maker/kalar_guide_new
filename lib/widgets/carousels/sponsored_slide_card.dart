// lib/widgets/carousels/sponsored_slide_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/tr.dart';
import '../../screens/stores/store_details_dialog.dart';
import '../../services/sponsored_slides_service.dart';
import '../common/optimized_network_image.dart';

/// 📢 سلایدی ڕیکلام: وێنە، ناونیشان، دوگمە و نیشانەی «ڕیکلام»
class SponsoredSlideCard extends StatelessWidget {
  const SponsoredSlideCard({super.key, required this.slide, this.onOpen});

  final SponsoredSlide slide;

  /// بۆ تاقیکردنەوە
  final void Function(SponsoredSlide s)? onOpen;

  Future<void> _open(BuildContext context) async {
    HapticFeedback.lightImpact();
    if (onOpen != null) return onOpen!(slide);
    if (slide.actionType == 'place') {
      unawaitedClick();
      final id = int.tryParse(slide.actionValue.trim());
      if (id == null) return;
      try {
        final row = await Supabase.instance.client.from('dukan').select().eq('id', id).maybeSingle();
        if (row != null && context.mounted) StoreDetailsDialog.show(context, row);
      } catch (_) {}
      return;
    }
    await SponsoredSlidesService.open(slide);
  }

  void unawaitedClick() => SponsoredSlidesService.recordClick(slide);

  @override
  Widget build(BuildContext context) {
    final s = slide;
    return Semantics(
      button: s.hasAction,
      label: '${tr('ڕیکلام')}: ${s.title}',
      child: GestureDetector(
        key: ValueKey('ad-${s.id}'),
        onTap: s.hasAction ? () => _open(context) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              OptimizedNetworkImage(imageUrl: s.imageUrl, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              // نیشانەی «ڕیکلام» — پێویستە بۆ ڕاستگۆیی و یاسای Google Play
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  key: const ValueKey('ad-label'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tr('ڕیکلام'),
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ),
              PositionedDirectional(
                start: 14,
                end: 14,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(s.title),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.3)),
                          if (s.subtitle.isNotEmpty)
                            Text(tr(s.subtitle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (s.hasAction) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tr(SponsoredSlide.actionLabel(s.actionType)),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87)),
                      ),
                    ],
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
