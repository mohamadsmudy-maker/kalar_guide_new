import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';

/// 🛒 دیالۆگی وردەکاری کاڵا
class ProductDetailsSheet {
  static void show(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailsSheet(product: product),
    );
  }
}

class _ProductDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  const _ProductDetailsSheet({required this.product});

  @override
  State<_ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<_ProductDetailsSheet> {
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isFav = false;
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    _checkIsFav();
  }

  Future<void> _checkIsFav() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) return;

    try {
      final res = await Supabase.instance.client
          .from('favorites')
          .select()
          .eq('user_id', user['id'])
          .eq('product_id', widget.product['id']);
      if (mounted) setState(() => _isFav = (res as List).isNotEmpty);
    } catch (_) {}
  }

  Future<void> _toggleFav() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە سەرەتا بچۆ ژوورەوە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (_isFav) {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', user['id'])
            .eq('product_id', widget.product['id']);
        if (mounted) {
          setState(() => _isFav = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لە دڵخوازەکان لادرا 💔")),
          );
        }
      } else {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': user['id'],
          'product_id': widget.product['id'],
        });
        if (mounted) {
          setState(() => _isFav = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("بۆ دڵخوازەکان زیادکرا ❤")),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _addToCart() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە سەرەتا بچۆ ژوورەوە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _addingToCart = true);
    try {
      await Supabase.instance.client.from('cart').insert({
        'user_id': user['id'],
        'product_id': widget.product['id'],
        'quantity': _quantity,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("زیادکرا بۆ سەبەتە 🛍"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  void _openFullScreenImage(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: OptimizedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final details = product['details'] is Map ? product['details'] : {};

    List<String> imagesList = [];
    if (product['images'] is List) {
      imagesList = List<String>.from(
        product['images'].map((e) => e.toString()),
      );
    }
    if (imagesList.isEmpty && product['img'] != null) {
      imagesList.add(product['img'].toString());
    }

    double basePrice = double.tryParse(
      product['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ??
          '0',
    ) ??
        0;
    double totalPrice = basePrice * _quantity;

    String? description = details['description']?.toString() ??
        product['description']?.toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.98,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 45,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // ═══════════════════════════════════════════════
                    // 🖼️ گەلەری وێنە — بە Hero Animation
                    // ═══════════════════════════════════════════════
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _openFullScreenImage(
                            imagesList,
                            _currentImageIndex,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 340,
                              child: PageView.builder(
                                itemCount: imagesList.length,
                                onPageChanged: (index) => setState(
                                      () => _currentImageIndex = index,
                                ),
                                itemBuilder: (context, index) {
                                  // ✅ یەکەم وێنە بە Hero، ئەوانی تر بێ Hero
                                  if (index == 0) {
                                    return Hero(
                                      tag: 'product_image_${product['id']}',
                                      child: OptimizedNetworkImage(
                                        imageUrl: imagesList[index],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return OptimizedNetworkImage(
                                    imageUrl: imagesList[index],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // ❤️ دڵخواز
                        Positioned(
                          top: 12,
                          left: 12,
                          child: InkWell(
                            onTap: _toggleFav,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(
                                _isFav
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFav
                                    ? Colors.redAccent
                                    : Colors.black87,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        // 🔍 زووم
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Indicators
                    if (imagesList.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imagesList.length,
                              (index) => Container(
                            width: _currentImageIndex == index ? 18 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // 📝 ناوی کاڵا
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 💰 کارتی نرخ
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.05),
                            AppColors.primary.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "نرخی تاک: ",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${product['price'] ?? ''} د.ع",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text(
                                    "کۆی گشتی: ",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${totalPrice.toStringAsFixed(0)} د.ع",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // 🔢 کۆنترۆلی بڕ
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (_quantity > 1) {
                                      setState(() => _quantity--);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "$_quantity",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _quantity++),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📄 وەسف
                    if (description != null && description.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "وەسفی کاڵا",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
              // 🛒 دوگمەی زیادکردن
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _addingToCart ? null : _addToCart,
                      icon: _addingToCart
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.add_shopping_cart, size: 20),
                      label: Text(
                        _addingToCart
                            ? "خەریکە زیاد دەکرێت..."
                            : "زیادکردن بۆ سەبەتە",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}