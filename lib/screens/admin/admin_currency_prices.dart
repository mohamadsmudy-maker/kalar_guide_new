import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../currency/currency_history_screen.dart';

/// 💰 نوێکردنەوەی نرخی نوسینگەی دراو + مێژوو
class AdminCurrencyPricesScreen extends StatefulWidget {
  final Map<String, dynamic> station;

  const AdminCurrencyPricesScreen({super.key, required this.station});

  @override
  State<AdminCurrencyPricesScreen> createState() =>
      _AdminCurrencyPricesScreenState();
}

class _AdminCurrencyPricesScreenState
    extends State<AdminCurrencyPricesScreen> {
  bool _loading = true;
  Map<String, dynamic> _currencyPrices = {};

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  void _loadPrices() {
    final prices = widget.station['currency_prices'];

    setState(() {
      _currencyPrices = prices is Map
          ? Map<String, dynamic>.from(prices)
          : <String, dynamic>{};
      _loading = false;
    });
  }

  void _openHistory(String? currencyType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencyHistoryScreen(
          stationId: widget.station['id'],
          stationName: widget.station['name']?.toString() ?? 'نوسینگە',
          currencyType: currencyType,
        ),
      ),
    );
  }

  Future<void> _updatePrice(String currencyType) async {
    final currentData = _currencyPrices[currencyType];
    final currentBuy = (currentData is Map)
        ? (currentData['buy'] as num?)?.toDouble() ?? 0
        : 0.0;
    final currentSell = (currentData is Map)
        ? (currentData['sell'] as num?)?.toDouble() ?? 0
        : 0.0;

    final buyCtrl = TextEditingController(
      text: currentBuy > 0 ? currentBuy.toStringAsFixed(0) : '',
    );
    final sellCtrl = TextEditingController(
      text: currentSell > 0 ? currentSell.toStringAsFixed(0) : '',
    );
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'نوێکردنەوەی نرخ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      CurrencyService.getNameKu(currencyType),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ℹ️ Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'نرخی ئێستا — کڕین: ${currentBuy.toStringAsFixed(0)} • فرۆشتن: ${currentSell.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 🛒 نرخی کڕین
                TextField(
                  controller: buyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نرخی کڕین (د.ع)',
                    prefixIcon: const Icon(
                      Icons.shopping_cart_rounded,
                      color: Color(0xFF1E88E5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E88E5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 💰 نرخی فرۆشتن
                TextField(
                  controller: sellCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نرخی فرۆشتن (د.ع)',
                    prefixIcon: const Icon(
                      Icons.sell_rounded,
                      color: Color(0xFF10B981),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 📝 تێبینی
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'تێبینی (ئارەزوومەندانە)',
                    hintText: 'بۆ نموونە: بەهۆی گۆڕانی بازاڕ',
                    prefixIcon: const Icon(
                      Icons.note_rounded,
                      color: Color(0xFF10B981),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('پاشگەزبوونەوە'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final newBuy = double.tryParse(buyCtrl.text) ?? 0;
                final newSell = double.tryParse(sellCtrl.text) ?? 0;

                if (newBuy < 0 || newSell < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('تکایە نرخێکی دروست بنووسە'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (newBuy == 0 && newSell == 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('تکایە لانیکەم یەک نرخ بنووسە'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final success = await CurrencyService.updatePrice(
                  stationId: widget.station['id'],
                  currencyType: currencyType,
                  newBuyPrice: newBuy,
                  newSellPrice: newSell,
                  updatedByName:
                  AuthSessionManager.userName ?? 'بەکارهێنەر',
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                );

                if (ctx.mounted && success) {
                  Navigator.pop(ctx, true);
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'پاشەکەوتکردن',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final updated = await CurrencyService.getStationPrices(
        widget.station['id'],
      );

      if (updated != null && mounted) {
        setState(() {
          _currencyPrices = updated['currency_prices'] is Map
              ? Map<String, dynamic>.from(updated['currency_prices'] as Map)
              : {};
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ نرخ نوێکرایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.station['name']?.toString() ?? 'نوسینگەی دراو';
    final address = widget.station['address']?.toString() ?? '';

    final currencyTypes = CurrencyService.currencyTypes;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'مێژووی هەموو نرخەکان',
              onPressed: () => _openHistory(null),
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStationHeader(name, address),
            const SizedBox(height: 20),
            _buildSectionTitle('جۆرەکانی دراو'),
            const SizedBox(height: 12),
            ...currencyTypes.map(
                  (type) => _buildPriceCard(type, isDark),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStationHeader(String name, String address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1B2E), Color(0xFF1B3D2F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Icon(
              Icons.attach_money_rounded,
              color: Color(0xFF0F1421),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF10B981),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> type, bool isDark) {
    final currencyType = type['key'] as String;
    final nameKu = type['name_ku'] as String;
    final color = _hexToColor(type['color'] as String);

    final data = _currencyPrices[currencyType];
    final buyPrice = (data is Map)
        ? (data['buy'] as num?)?.toDouble() ?? 0
        : 0.0;
    final sellPrice = (data is Map)
        ? (data['sell'] as num?)?.toDouble() ?? 0
        : 0.0;
    final hasPrice = buyPrice > 0 || sellPrice > 0;

    return GestureDetector(
      onTap: () => _updatePrice(currencyType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nameKu,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            size: 11,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'کلیک بکە بۆ دەستکاری',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (buyPrice > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'کڕین: ${buyPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    if (sellPrice > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasPrice
                                ? [color, color.withValues(alpha: 0.8)]
                                : [
                              Colors.grey.shade400,
                              Colors.grey.shade500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'فرۆشتن: ${sellPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    if (!hasPrice)
                      const Text(
                        '--',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (hasPrice) ...[
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openHistory(currencyType),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: color,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'بینینی مێژووی گۆڕانکاری',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: color,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }
}