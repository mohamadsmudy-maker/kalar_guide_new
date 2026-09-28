import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/fuel_station.dart';
import '../../models/fuel_price_history.dart';
import '../../services/fuel_service.dart';

/// 🛢️ پانێڵی ئەدمین — بەڕێوەبردنی بەنزینخانەکان
class AdminFuelScreen extends StatefulWidget {
  const AdminFuelScreen({super.key});

  @override
  State<AdminFuelScreen> createState() => _AdminFuelScreenState();
}

class _AdminFuelScreenState extends State<AdminFuelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FuelStation> _stations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stations = await FuelService.getAllStations();
    if (mounted) {
      setState(() {
        _stations = stations;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'بەڕێوەبردنی سووتەمەنی',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.primary,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(
              text: 'بەنزینخانەکان',
              icon: Icon(Icons.local_gas_station_rounded),
            ),
            Tab(text: 'مێژوو', icon: Icon(Icons.history_rounded)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStationsTab(isDark),
          _buildHistoryTab(isDark),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
        onPressed: () => _showStationDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('زیادکردن'),
      )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════
  // 🏢 Tab ی بەنزینخانەکان
  // ═══════════════════════════════════════════════════
  Widget _buildStationsTab(bool isDark) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_stations.isEmpty) {
      return const Center(child: Text('هیچ بەنزینخانەیەک نییە'));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stations.length,
        itemBuilder: (context, index) =>
            _buildStationTile(_stations[index], isDark),
      ),
    );
  }

  Widget _buildStationTile(FuelStation station, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.nameKu,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (station.address != null)
                      Text(
                        station.address!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'دەستکاریکردنی زانیاری',
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                ),
                onPressed: () => _showStationDialog(station: station),
              ),
              IconButton(
                tooltip: 'سڕینەوە',
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                onPressed: () => _confirmDelete(station),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              if (station.isVerified) _buildTag('پارێزراو', Colors.blue),
              const SizedBox(width: 6),
              if (station.isFeatured) _buildTag('تایبەت', Colors.orange),
              const Spacer(),
              // ✅ دوگمەی نوێکردنەوەی نرخ
              GestureDetector(
                onTap: () => _showUpdatePriceDialog(station),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'نوێکردنەوەی نرخ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 📊 Tab ی مێژوو
  // ═══════════════════════════════════════════════════
  Widget _buildHistoryTab(bool isDark) {
    return FutureBuilder<List<FuelPriceHistory>>(
      future: FuelService.getMonthlyHistory(monthsBack: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 80,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'هیچ مێژوویەک نییە',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        final history = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.fuelType} - ${item.price.toStringAsFixed(0)} د.ع',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '${item.updatedByName ?? ''} - ${_formatDate(item.createdAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // ⚡ دیالۆگی نوێکردنەوەی نرخ
  // ═══════════════════════════════════════════════════
  Future<void> _showUpdatePriceDialog(FuelStation station) async {
    // 📥 وەرگرتنی نرخەکانی ئێستا
    final prices = await FuelService.getStationPrices(station.id!);

    if (prices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هیچ نرخێک نییە بۆ ئەم بەنزینخانە'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    String selectedFuel = prices.first.fuelType;
    final priceCtrl = TextEditingController(
      text: prices.first.price.toStringAsFixed(0),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'نوێکردنەوەی نرخی ${station.nameKu}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🏷️ جۆری سووتەمەنی
                DropdownButtonFormField<String>(
                  value: selectedFuel,
                  decoration: InputDecoration(
                    labelText: 'جۆری سووتەمەنی',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.local_gas_station_rounded),
                  ),
                  items: prices.map((p) {
                    return DropdownMenuItem(
                      value: p.fuelType,
                      child: Text(p.fuelType),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setStateDialog(() {
                        selectedFuel = v;
                        final p =
                        prices.firstWhere((e) => e.fuelType == v);
                        priceCtrl.text = p.price.toStringAsFixed(0);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // 💰 نرخی نوێ
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'نرخی نوێ (د.ع)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money_rounded),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final newPrice = double.tryParse(priceCtrl.text);
                  if (newPrice == null || newPrice < 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('تکایە نرخێکی دروست بنووسە'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final success = await FuelService.updatePrice(
                    stationId: station.id!,
                    fuelType: selectedFuel,
                    newPrice: newPrice,
                    updatedByName: 'ئەدمین',
                  );

                  if (ctx.mounted && success) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text(
                  'نوێکردنەوە',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نرخ بە سەرکەوتوویی نوێکرایەوە ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════
  // 💬 دیالۆگی بەنزینخانە
  // ═══════════════════════════════════════════════════
  Future<void> _showStationDialog({FuelStation? station}) async {
    final isEditing = station != null;
    final nameKuCtrl = TextEditingController(text: station?.nameKu ?? '');
    final nameArCtrl = TextEditingController(text: station?.nameAr ?? '');
    final nameEnCtrl = TextEditingController(text: station?.nameEn ?? '');
    final addressCtrl = TextEditingController(text: station?.address ?? '');
    final phoneCtrl = TextEditingController(text: station?.phone ?? '');

    bool isVerified = station?.isVerified ?? false;
    bool isFeatured = station?.isFeatured ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title:
            Text(isEditing ? 'دەستکاریکردن' : 'زیادکردنی بەنزینخانە'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildField(nameKuCtrl, 'ناوی کوردی *'),
                  _buildField(nameArCtrl, 'ناوی عەرەبی'),
                  _buildField(nameEnCtrl, 'ناوی ئینگلیزی'),
                  _buildField(addressCtrl, 'ناونیشان'),
                  _buildField(phoneCtrl, 'ژمارەی مۆبایل'),
                  SwitchListTile(
                    value: isVerified,
                    onChanged: (v) =>
                        setStateDialog(() => isVerified = v),
                    title: const Text(
                      'پارێزراو',
                      style: TextStyle(fontSize: 13),
                    ),
                    activeThumbColor: Colors.blue,
                  ),
                  SwitchListTile(
                    value: isFeatured,
                    onChanged: (v) =>
                        setStateDialog(() => isFeatured = v),
                    title: const Text(
                      'تایبەت',
                      style: TextStyle(fontSize: 13),
                    ),
                    activeThumbColor: Colors.orange,
                  ),
                ],
              ),
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
                  if (nameKuCtrl.text.trim().isEmpty) return;

                  final newStation = FuelStation(
                    id: station?.id,
                    nameKu: nameKuCtrl.text.trim(),
                    nameAr: nameArCtrl.text.trim(),
                    nameEn: nameEnCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty
                        ? null
                        : addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    isVerified: isVerified,
                    isFeatured: isFeatured,
                  );

                  final success = isEditing
                      ? await FuelService.updateStation(newStation)
                      : await FuelService.addStation(newStation);

                  if (ctx.mounted && success) Navigator.pop(ctx, true);
                },
                child: Text(isEditing ? 'نوێکردنەوە' : 'زیادکردن'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) _load();
  }

  Future<void> _confirmDelete(FuelStation station) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سڕینەوە'),
          content: Text('ئایا دڵنیایت لە سڕینەوەی "${station.nameKu}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('پاشگەزبوونەوە'),
            ),
            TextButton(
              onPressed: () async {
                final success =
                await FuelService.deleteStation(station.id!);
                if (ctx.mounted && success) Navigator.pop(ctx, true);
              },
              child: const Text(
                'سڕینەوە',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) _load();
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          isDense: true,
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
}