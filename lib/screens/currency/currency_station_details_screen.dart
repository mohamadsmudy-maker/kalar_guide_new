import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/currency_service.dart';

/// 🏢 شاشەی وردەکاری نوسینگەی دراو
class CurrencyStationDetailsScreen extends StatefulWidget {
  final int stationId;

  const CurrencyStationDetailsScreen({super.key, required this.stationId});

  @override
  State<CurrencyStationDetailsScreen> createState() =>
      _CurrencyStationDetailsScreenState();
}

class _CurrencyStationDetailsScreenState
    extends State<CurrencyStationDetailsScreen> {
  Map<String, dynamic>? _station;
  Map<String, dynamic> _currencyPrices = {};
  bool _loadingStation = true;

  @override
  void initState() {
    super.initState();
    _loadStation();
  }

  Future<void> _loadStation() async {
    setState(() => _loadingStation = true);
    try {
      final station = await CurrencyService.getStationPrices(widget.stationId);

      if (mounted) {
        setState(() {
          _station = station;
          _currencyPrices = (station?['currency_prices'] is Map)
              ? Map<String, dynamic>.from(station!['currency_prices'] as Map)
              : <String, dynamic>{};
          _loadingStation = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _loadingStation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            _station?['name']?.toString() ?? 'نوسینگەی دراو',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: _loadingStation
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : _station == null
            ? const Center(
          child: Text(
            'نوسینگە نەدۆزرایەوە',
            style: TextStyle(color: Colors.grey),
          ),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStationInfoCard(_station!, isDark, lang),
            const SizedBox(height: 16),
            Text(
              'نرخەکانی ئێستا',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (_currencyPrices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'هیچ نرخێک نییە',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._currencyPrices.entries.map((entry) {
                final data = entry.value;
                if (data is! Map) return const SizedBox.shrink();
                final buy = (data['buy'] as num?)?.toDouble() ?? 0;
                final sell = (data['sell'] as num?)?.toDouble() ?? 0;
                return _buildPriceTile(
                  entry.key,
                  buy,
                  sell,
                  isDark,
                );
              }),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _currencyPrices.isEmpty
                  ? null
                  : () => _showUpdatePriceDialog(isDark),
              icon: const Icon(Icons.edit_rounded),
              label: const Text(
                'نوێکردنەوەی نرخ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'مێژووی نرخەکان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildHistoryList(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoCard(
      Map<String, dynamic> station,
      bool isDark,
      String lang,
      ) {
    final name = station['name']?.toString() ?? 'نوسینگەی دراو';
    final address = station['address']?.toString();
    final phone = station['phone']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceTile(
      String currencyType,
      double buyPrice,
      double sellPrice,
      bool isDark,
      ) {
    final color = _hexToColor(CurrencyService.getColorForType(currencyType));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.attach_money_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              CurrencyService.getNameKu(currencyType),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (sellPrice > 0)
                Text(
                  'فرۆشتن: ${sellPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              if (buyPrice > 0)
                Text(
                  'کڕین: ${buyPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: CurrencyService.getStationPriceHistory(
        stationId: widget.stationId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'هیچ مێژوویەک نییە',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: history.take(20).map((item) {
            final currencyType = item['currency_type']?.toString() ?? '';
            final newSell = (item['new_sell_price'] as num?)?.toDouble() ?? 0;
            final newBuy = (item['new_buy_price'] as num?)?.toDouble() ?? 0;
            final createdAt = item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString())
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyService.getNameKu(currencyType),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (newSell > 0)
                        Text(
                          'ف: ${newSell.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      if (newBuy > 0)
                        Text(
                          'ک: ${newBuy.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showUpdatePriceDialog(bool isDark) async {
    if (_currencyPrices.isEmpty) return;

    final currencyTypesList = _currencyPrices.keys.toList();
    String selectedCurrency = currencyTypesList.first;

    final currentData = _currencyPrices[selectedCurrency];
    final currentBuy = (currentData is Map)
        ? (currentData['buy'] as num?)?.toDouble() ?? 0
        : 0.0;
    final currentSell = (currentData is Map)
        ? (currentData['sell'] as num?)?.toDouble() ?? 0
        : 0.0;

    final buyCtrl = TextEditingController(text: currentBuy.toStringAsFixed(0));
    final sellCtrl =
    TextEditingController(text: currentSell.toStringAsFixed(0));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'نوێکردنەوەی نرخ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'جۆری دراو',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: currencyTypesList.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(CurrencyService.getNameKu(type)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setStateDialog(() {
                        selectedCurrency = v;
                        final data = _currencyPrices[v];
                        final b = (data is Map)
                            ? (data['buy'] as num?)?.toDouble() ?? 0
                            : 0.0;
                        final s = (data is Map)
                            ? (data['sell'] as num?)?.toDouble() ?? 0
                            : 0.0;
                        buyCtrl.text = b.toStringAsFixed(0);
                        sellCtrl.text = s.toStringAsFixed(0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: buyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نرخی کڕین',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.shopping_cart_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sellCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'نرخی فرۆشتن',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.sell_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('پاشگەزبوونەوە'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final newBuy = double.tryParse(buyCtrl.text) ?? 0;
                  final newSell = double.tryParse(sellCtrl.text) ?? 0;

                  if (newBuy < 0 || newSell < 0) return;

                  final success = await CurrencyService.updatePrice(
                    stationId: widget.stationId,
                    currencyType: selectedCurrency,
                    newBuyPrice: newBuy,
                    newSellPrice: newSell,
                    updatedByName: 'بەکارهێنەر',
                  );

                  if (ctx.mounted && success) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('نوێکردنەوە'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadStation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نرخ نوێکرایەوە ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}