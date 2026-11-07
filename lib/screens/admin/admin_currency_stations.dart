import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import 'admin_currency_prices.dart';

/// 🏢 لیستی نوسینگەکانی دراو (لە `dukan`)
class AdminCurrencyStationsScreen extends StatefulWidget {
  const AdminCurrencyStationsScreen({super.key});

  @override
  State<AdminCurrencyStationsScreen> createState() =>
      _AdminCurrencyStationsScreenState();
}

class _AdminCurrencyStationsScreenState
    extends State<AdminCurrencyStationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stations = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    try {
      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;

      List<Map<String, dynamic>> stations;

      if (role == 'vendor' && user != null) {
        final phone = user['phone']?.toString() ?? '';
        stations = await CurrencyService.getVendorStations(phone);
      } else {
        stations = await CurrencyService.getAllStations();
      }

      if (mounted) {
        setState(() {
          _stations = stations;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStations {
    if (_searchQuery.isEmpty) return _stations;
    final q = _searchQuery.toLowerCase();
    return _stations.where((s) {
      return (s['name']?.toString().toLowerCase().contains(q) ?? false) ||
          (s['address']?.toString().toLowerCase().contains(q) ?? false) ||
          (s['phone']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final role = AuthSessionManager.userRole;
    final isVendor = role == 'vendor';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            isVendor
                ? 'نوسینگەکەم'
                : 'نوسینگەکانی دراو (${_stations.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadStations,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        )
            : Column(
          children: [
            if (!isVendor)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1B2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'گەڕان بەدوای نوسینگەکان...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF10B981),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _filteredStations.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                color: const Color(0xFF10B981),
                onRefresh: _loadStations,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredStations.length,
                  itemBuilder: (context, index) => _buildStationCard(
                    _filteredStations[index],
                    isDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station, bool isDark) {
    final name = station['name']?.toString() ?? 'نوسینگە';
    final address = station['address']?.toString() ?? '';
    final image = station['image']?.toString() ?? '';
    final logo = station['logo']?.toString() ?? '';
    final prices = station['currency_prices'] as Map? ?? {};

    // ⭐ نرخی دۆلار وەک پێشبینین
    final usdData = prices['usd'];
    final usdSell = usdData is Map
        ? (usdData['sell'] as num?)?.toDouble() ?? 0
        : 0;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminCurrencyPricesScreen(station: station),
          ),
        );
        if (result == true) _loadStations();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: (image.isNotEmpty || logo.isNotEmpty)
                  ? Image.network(
                image.isNotEmpty ? image : logo,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultIcon(),
              )
                  : _buildDefaultIcon(),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (usdSell > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'دۆلار: ${usdSell.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.attach_money_rounded,
        color: Color(0xFF0F1421),
        size: 28,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ نوسینگەیەک نەدۆزرایەوە',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}