import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_colors.dart';
import '../screens/products/product_details.dart';
import 'common/optimized_network_image.dart';

/// ⚡ کارتی سەرسوڕمانی ڕۆژ
class FlashSaleCard extends StatefulWidget {
  final bool isPopup;
  const FlashSaleCard({super.key, this.isPopup = false});

  @override
  State<FlashSaleCard> createState() => _FlashSaleCardState();
}

class _FlashSaleCardState extends State<FlashSaleCard> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchTodayOffers();
    _calc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calc());
  }

  void _calc() {
    final now = DateTime.now();
    var end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (now.isAfter(end)) end = end.add(const Duration(days: 1));
    if (mounted) setState(() => _remaining = end.difference(now));
  }

  Future<void> _fetchTodayOffers() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final res = await Supabase.instance.client
          .from('daily_offers')
          .select('*, products(*)')
          .eq('offer_date', today)
          .eq('is_active', true);

      List<Map<String, dynamic>> fetched =
      List<Map<String, dynamic>>.from(res);

      if (mounted) {
        setState(() {
          _items = fetched;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_items.isEmpty) return const SizedBox.shrink();

    if (!widget.isPopup) {
      return GestureDetector(
        onTap: () => showFlashSalePopup(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Colors.amber,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                "سەرسوڕمانی ڕۆژ ⚡",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              _tBox(_two(_remaining.inHours)),
              const Text(
                ":",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _tBox(_two(_remaining.inMinutes.remainder(60))),
              const Text(
                ":",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _tBox(_two(_remaining.inSeconds.remainder(60))),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 14,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tBox(_two(_remaining.inHours)),
            const Text(
              " : ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            _tBox(_two(_remaining.inMinutes.remainder(60))),
            const Text(
              " : ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            _tBox(_two(_remaining.inSeconds.remainder(60))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: _items.map((item) {
            final prod =
            item['products'] is Map ? item['products'] : <String, dynamic>{};
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (prod.isNotEmpty) {
                      ProductDetailsSheet.show(context, prod);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: OptimizedNetworkImage(
                            imageUrl: prod['img'] ?? '',
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod['name'] ?? 'کاڵا',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "${item['original_price']}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${item['offer_price']} د.ع",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _tBox(String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      v,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 12,
        color: Colors.black,
      ),
    ),
  );
}

/// 🎨 پیشاندانی پۆپئاپی سەرسوڕمانی ڕۆژ
void showFlashSalePopup(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.sizeOf(context).width * 0.95,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "سەرسوڕمانی ڕۆژ ⚡",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "باشترین نرخەکان و ئۆفەری تایبەت تەنها بۆ ئەمڕۆ پەلە بکە!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 410),
                  child: const FlashSaleCard(isPopup: true),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}