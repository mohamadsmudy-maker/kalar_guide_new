import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';

/// 🛍️ شاشەی سەبەتەی کڕین
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('cart')
          .select('*, products(*)')
          .eq('user_id', user['id']);

      Map<String, Map<String, dynamic>> groupedMap = {};
      for (var row in (res as List)) {
        var prod = row['products'];
        if (prod == null) continue;
        String prodId = prod['id'].toString();
        int qty = int.tryParse(row['quantity'].toString()) ?? 1;

        if (groupedMap.containsKey(prodId)) {
          int existingQty =
              int.tryParse(groupedMap[prodId]!['quantity'].toString()) ?? 1;
          groupedMap[prodId]!['quantity'] = existingQty + qty;
          Supabase.instance.client
              .from('cart')
              .delete()
              .eq('id', row['id'])
              .then((_) {});
        } else {
          groupedMap[prodId] = Map<String, dynamic>.from(row);
        }
      }

      if (mounted) {
        setState(() {
          _cartItems = groupedMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (var row in _cartItems) {
      double price =
          double.tryParse(row['products']['price'].toString()) ?? 0;
      int qty = int.tryParse(row['quantity'].toString()) ?? 1;
      total += price * qty;
    }
    return total;
  }

  Future<void> _updateQty(int index, int newQty) async {
    var cartRow = _cartItems[index];
    if (newQty <= 0) {
      setState(() => _cartItems.removeAt(index));
      await Supabase.instance.client
          .from('cart')
          .delete()
          .eq('product_id', cartRow['product_id'])
          .eq('user_id', AuthSessionManager.currentUser!['id']);
    } else {
      setState(() => _cartItems[index]['quantity'] = newQty);
      await Supabase.instance.client
          .from('cart')
          .update({'quantity': newQty})
          .eq('product_id', cartRow['product_id'])
          .eq('user_id', AuthSessionManager.currentUser!['id']);
    }
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) return;
    setState(() => _isPlacingOrder = true);
    final user = AuthSessionManager.currentUser;
    final profile = await AuthSessionManager.fetchUserProfile();

    try {
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var item in _cartItems) {
        String sid = (item['products']['store_id'] ?? '0').toString();
        grouped.putIfAbsent(sid, () => []).add(item);
      }

      for (var entry in grouped.entries) {
        final store = await Supabase.instance.client
            .from('dukan')
            .select()
            .eq('id', entry.key)
            .maybeSingle();

        double storeTotal = 0;
        for (var r in entry.value) {
          storeTotal +=
              (double.tryParse(r['products']['price'].toString()) ?? 0) *
                  (int.tryParse(r['quantity'].toString()) ?? 1);
        }

        await Supabase.instance.client.from('orders').insert({
          'customer_name':
          profile?['name'] ?? user?['name'] ?? 'کڕیار',
          'customer_phone': profile?['phone'] ?? user?['phone'] ?? '',
          'user_id': user?['id'].toString(),
          'store_id': entry.key,
          'store_name': store?['name'] ?? 'فرۆشگا',
          'total_price': storeTotal,
          'items': entry.value
              .map((e) => {
            'product_id': e['products']['id'],
            'name': e['products']['name'],
            'price': e['products']['price'],
            'qty': e['quantity'],
            'img': e['products']['img'],
          })
              .toList(),
          'status': 'pending',
        });
      }

      await Supabase.instance.client
          .from('cart')
          .delete()
          .eq('user_id', user!['id']);

      if (mounted) {
        setState(() => _cartItems = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ئۆردەرەکەت تۆمارکرا ✅"),
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
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = AppColors.primary;
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: brandColor),
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("سەبەتە 🛒"),
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "سەبەتەکەت بەتاڵە! 🛒",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F8),
      appBar: AppBar(
        title: const Text("سەبەتە 🛒"),
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                var cartRow = _cartItems[index];
                var item = cartRow['products'] ?? {};
                int qty = int.tryParse(cartRow['quantity'].toString()) ?? 1;
                double price = double.tryParse(item['price'].toString()) ?? 0;

                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: OptimizedNetworkImage(
                        imageUrl: item['img'] ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      "${price.toStringAsFixed(0)} د.ع x $qty = ${(price * qty).toStringAsFixed(0)} د.ع",
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _updateQty(index, qty - 1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove, size: 16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "$qty",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _updateQty(index, qty + 1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: brandColor,
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
                );
              },
            ),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "کۆی گشتی:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${_calculateTotal().toStringAsFixed(0)} د.ع",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: brandColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _isPlacingOrder
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: brandColor,
                      ),
                    )
                        : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _placeOrder,
                      icon: const Icon(Icons.shopping_bag_rounded),
                      label: const Text(
                        "داواکردنی ئۆردەر ✅",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}