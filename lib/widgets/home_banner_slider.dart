import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_colors.dart';
import '../screens/stores/store_details_dialog.dart';
import '../screens/products/product_details.dart';
import 'common/optimized_network_image.dart';

/// 🎨 سلایدەری سەرەکی پڕۆفیشناڵ
class HomeBannerSlider extends StatefulWidget {
  const HomeBannerSlider({super.key});

  @override
  State<HomeBannerSlider> createState() => _HomeBannerSliderState();
}

class _HomeBannerSliderState extends State<HomeBannerSlider> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _timer;
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_pageController.page == null) return;

      int nextPageIndex =
          (_pageController.page!.round() + 1) % _banners.length;

      _pageController.animateToPage(
        nextPageIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _fetchBanners() async {
    try {
      final response = await Supabase.instance.client
          .from('banners')
          .select()
          .order('sort_order', ascending: true)
          .limit(5);

      List<Map<String, dynamic>> fetched =
      List<Map<String, dynamic>>.from(response);

      var validBanners = fetched.where((b) {
        final img = b['image']?.toString() ?? '';
        return img.isNotEmpty && img != 'EMPTY';
      }).toList();

      if (mounted) {
        setState(() {
          _banners = validBanners;
          _isLoading = false;
        });
        if (_banners.isNotEmpty) {
          _startAutoPlay();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onBannerTap(Map<String, dynamic> banner) async {
    // 🏪 ئەگەر شوێنە
    if (banner['store_id'] != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      try {
        final store = await Supabase.instance.client
            .from('dukan')
            .select()
            .eq('id', banner['store_id'])
            .maybeSingle();

        if (mounted) Navigator.pop(context);
        if (store != null && mounted) {
          StoreDetailsDialog.show(context, store);
        }
      } catch (_) {
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // 🛍️ ئەگەر کاڵایە
    if (banner['product_id'] != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      try {
        final prod = await Supabase.instance.client
            .from('products')
            .select()
            .eq('id', banner['product_id'])
            .maybeSingle();

        if (mounted) Navigator.pop(context);
        if (prod != null && mounted) {
          ProductDetailsSheet.show(context, prod);
        }
      } catch (_) {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_banners.isEmpty) {
      // ✅ سلایدەری بەتاڵ (Loading Shimmer)
      return _buildEmptyBanner();
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              var banner = _banners[index];
              return AnimatedScale(
                scale: _currentPage == index ? 1.0 : 0.94,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: () => _onBannerTap(banner),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 🖼️ وێنەی باکگراوند
                          OptimizedNetworkImage(
                            imageUrl: banner['image'] ?? '',
                            fit: BoxFit.cover,
                          ),

                          // 🌑 Gradient بۆ خوێندنەوەی دەق
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.85),
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // 🏷️ ناونیشان و نرخ (خوارەوە)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            left: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (banner['title'] != null &&
                                    banner['title'].toString().isNotEmpty)
                                  Text(
                                    banner['title'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (banner['price'] != null &&
                                    banner['price'].toString().isNotEmpty &&
                                    banner['price'].toString() != '0') ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${banner['price']} د.ع",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // 🔢 ژمارەی سلاید (سەرەوەی ڕاست)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                "${index + 1}/${_banners.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // ✨ باجی "نوێ" (سەرەوەی چەپ)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE91E63),
                                    Color(0xFF9C27B0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    "نوێ",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // 🔘 ئیندیکەیتەرەکان
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
                (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _currentPage == i ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: _currentPage == i
                    ? const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                )
                    : null,
                color: _currentPage == i ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _currentPage == i
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ سلایدەری بەتاڵ (Shimmer)
  Widget _buildEmptyBanner() {
    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 50,
                  color: Colors.grey,
                ),
                SizedBox(height: 10),
                Text(
                  "هیچ سلایدێک نییە",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}