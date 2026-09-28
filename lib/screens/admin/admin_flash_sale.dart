import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/common/optimized_network_image.dart';

/// ⚡ شاشەی بەڕێوەبردنی سەرسوڕمانی ڕۆژ
class AdminFlashSaleScreen extends StatefulWidget {
  const AdminFlashSaleScreen({super.key});

  @override
  State<AdminFlashSaleScreen> createState() => _AdminFlashSaleScreenState();
}

class _AdminFlashSaleScreenState extends State<AdminFlashSaleScreen> {
  List<Map<String, dynamic>> _slots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final res = await Supabase.instance.client
          .from('daily_offers')
          .select('*, products(*)')
          .eq('offer_date', today);

      if (mounted) {
        setState(() {
          _slots = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSlot(dynamic slotId) async {
    await Supabase.instance.client
        .from('daily_offers')
        .delete()
        .eq('id', slotId);
    _fetchSlots();
  }

  void _openProductPicker(int slotNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProductPickerSheet(
        slotNumber: slotNumber,
        onSelected: () => _fetchSlots(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            'سەرسوڕمانی ڕۆژ ⚡',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: const Color(0xFFE91E63),
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchSlots,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
        )
            : Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            itemCount: 4,
            itemBuilder: (context, index) {
              final slotNumber = index + 1;
              final match = _slots.firstWhere(
                    (s) => s['slot_index'] == slotNumber,
                orElse: () => {},
              );
              final prod = match['products'] ?? {};
              final hasProduct = match.isNotEmpty && prod.isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: hasProduct
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: OptimizedNetworkImage(
                      imageUrl: prod['img'] ?? '',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  )
                      : CircleAvatar(
                    backgroundColor:
                    hasProduct
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    child: Text(
                      "$slotNumber",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasProduct
                            ? Colors.green.shade800
                            : Colors.grey,
                      ),
                    ),
                  ),
                  title: Text(
                    hasProduct
                        ? (prod['name'] ?? 'کاڵا')
                        : "سلۆتی $slotNumber - بەتاڵە",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                      hasProduct ? Colors.black87 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    hasProduct
                        ? "نرخی داشکاندن: ${match['offer_price']} د.ع"
                        : "کرتە بکە بۆ زیادکردنی کاڵا",
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasProduct)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _deleteSlot(match['id']),
                        ),
                      IconButton(
                        icon: Icon(
                          hasProduct ? Icons.edit : Icons.add_circle,
                          color: const Color(0xFFE91E63),
                        ),
                        onPressed: () => _openProductPicker(slotNumber),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final int slotNumber;
  final VoidCallback onSelected;

  const _ProductPickerSheet({
    required this.slotNumber,
    required this.onSelected,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select()
          .order('id', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(res);
          _filtered = _products;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selected == null || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە کاڵا و نرخی داشکاندن دیاری بکە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T')[0];

      await supabase
          .from('daily_offers')
          .delete()
          .eq('offer_date', today)
          .eq('slot_index', widget.slotNumber);

      await supabase.from('daily_offers').insert({
        'slot_index': widget.slotNumber,
        'product_id': _selected!['id'],
        'original_price': num.tryParse(
          _selected!['price']?.toString().replaceAll(
            RegExp(r'[^0-9.]'),
            '',
          ) ??
              '0',
        ) ??
            0,
        'offer_price': num.tryParse(
          _priceCtrl.text.trim().replaceAll(
            RegExp(r'[^0-9.]'),
            '',
          ),
        ) ??
            0,
        'offer_date': today,
        'is_active': true,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSelected();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("پاشەکەوتکرا ✅"),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "سلۆتی ${widget.slotNumber}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _filtered = _products
                  .where((p) => (p['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(v.toLowerCase()))
                  .toList();
            }),
            decoration: InputDecoration(
              hintText: "گەڕان بەدوای کاڵاکان...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 12),
          if (_selected != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "هەڵبژێردرا: ${_selected!['name']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "نرخی داشکاندن (د.ع)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _save,
                      child: const Text("پاشەکەوتکردن ✅"),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                var p = _filtered[i];
                bool isSel = _selected?['id'] == p['id'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selected = p;
                      _priceCtrl.text = p['price']?.toString() ?? '';
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel
                            ? const Color(0xFFE91E63)
                            : Colors.grey.shade300,
                        width: isSel ? 2 : 1,
                      ),
                      color: isSel ? Colors.pink.shade50 : Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: OptimizedNetworkImage(
                              imageUrl: p['img'] ?? '',
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${p['price']} د.ع",
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}