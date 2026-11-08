import 'package:flutter/material.dart';
import '../../models/store_service.dart';
import '../../services/store_service_service.dart';
import 'service_details_screen.dart';
import '../../l10n/tr.dart';

/// 📋 شاشەی لیستی مامەڵەکانی شوێن
class StoreServicesScreen extends StatefulWidget {
  final int storeId;
  final String storeName;

  const StoreServicesScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreServicesScreen> createState() => _StoreServicesScreenState();
}

class _StoreServicesScreenState extends State<StoreServicesScreen> {
  bool _loading = true;
  List<StoreService> _services = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await StoreServiceService.getStoreServices(widget.storeId);
    if (mounted) {
      setState(() {
        _services = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            trf('مامەڵەکانی {0}', [widget.storeName]),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1E88E5),
          ),
        )
            : _services.isEmpty
            ? _buildEmpty(isDark)
            : RefreshIndicator(
          color: const Color(0xFF1E88E5),
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _services.length,
            itemBuilder: (ctx, i) =>
                _buildServiceCard(_services[i], isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(StoreService service, bool isDark) {
    Color color;
    try {
      String hex = service.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      color = Color(int.parse(hex, radix: 16));
    } catch (_) {
      color = const Color(0xFF1E88E5);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceDetailsScreen(service: service),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🎨 ئایکۆن
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
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
              child: Icon(
                _getIconData(service.icon),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // 📝 زانیاری
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(service.titleKu),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color:
                      isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (service.description != null &&
                      service.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tr(service.description!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 💰 ژمارەی تێچوو
                      if (service.fees.isNotEmpty)
                        _buildSmallBadge(
                          Icons.attach_money_rounded,
                          trf('{0} تێچوو', [service.fees.length]),
                          const Color(0xFF0F9D7A),
                        ),
                      const SizedBox(width: 6),
                      // 📄 ژمارەی پێداویستی
                      if (service.requirements.isNotEmpty)
                        _buildSmallBadge(
                          Icons.checklist_rounded,
                          trf('{0} پێداویستی', [service.requirements.length]),
                          const Color(0xFF4F5BD5),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: color,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            tr(label),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'car':
        return Icons.directions_car_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'money':
        return Icons.attach_money_rounded;
      case 'id_card':
        return Icons.badge_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 60,
              color: Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('هیچ مامەڵەیەک نییە'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('هێشتا مامەڵە بۆ ئەم شوێنە زیاد نەکراوە'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}