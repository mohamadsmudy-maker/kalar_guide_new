import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/emergency_service.dart';
import '../../models/emergency_categories.dart';
import '../../services/emergency_service.dart';

/// 🚨 شاشەی فریاکەوتن — ULTRA PRO
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _loading = true;
  List<EmergencyService> _services = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    final data = await EmergencyServiceRepository.getAll();
    if (mounted) {
      setState(() {
        _services = data;
        _loading = false;
      });
    }
  }

  Future<void> _call(String phone) async {
    HapticFeedback.heavyImpact();
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('❌ Call error: $e');
    }
  }

  List<EmergencyService> get _filtered {
    return _services.where((s) {
      if (_selectedCategory != 'all' && s.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!s.nameKu.toLowerCase().contains(q) &&
            !s.phone.toLowerCase().contains(q) &&
            !(s.authorityName ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return s.isActive;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'ژمارەکانی فریاکەوتن 🚨',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Column(
          children: [
            // ═══ Search ═══
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim()),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'گەڕان بەدوای ژمارە...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFDC2626),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // ═══ Category Filter ═══
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: EmergencyCategories.categories.length,
                itemBuilder: (context, i) {
                  final cat = EmergencyCategories.categories[i];
                  final isSelected = _selectedCategory == cat['key'];

                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat['key']!);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                            colors: [
                              Color(0xFFDC2626),
                              Color(0xFFFF7043),
                            ],
                          )
                              : null,
                          color: isSelected
                              ? null
                              : (isDark
                              ? const Color(0xFF1A1A22)
                              : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade200),
                          ),
                        ),
                        child: Text(
                          cat['name']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                ? Colors.white70
                                : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ═══ List ═══
            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFDC2626),
                ),
              )
                  : _filtered.isEmpty
                  ? _buildEmpty(isDark)
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _filtered.length,
                itemBuilder: (context, i) =>
                    _buildCard(_filtered[i], isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(EmergencyService service, bool isDark) {
    final color = _hexToColor(service.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _call(service.phone),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                    shape: BoxShape.circle,
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
                        service.nameKu,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 13,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            service.phone,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (service.authorityName != null &&
                          service.authorityName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          service.authorityName!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_outlined,
              size: 60,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ ژمارەیەک نەدۆزرایەوە',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'local_police':
        return Icons.local_police_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'bolt':
        return Icons.electric_bolt_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.emergency_rounded;
    }
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFDC2626);
    }
  }
}