import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/emergency_service.dart';
import '../../services/emergency_service.dart';
import '../../widgets/emergency/emergency_card.dart';

/// 🚑 شاشەی خزمەتگوزاری فریاکەوتن
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<EmergencyService> _services = [];
  String _selectedCategory = 'all';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadServices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _loading = true);
    final data = await EmergencyServiceService.getAll();
    if (mounted) {
      setState(() {
        _services = data;
        _loading = false;
      });
    }
  }

  List<EmergencyService> get _filteredServices {
    if (_selectedCategory == 'all') return _services;
    return _services.where((s) => s.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            // ═══════════════════════════════════════
            // 🎨 هێدەری ئاڵەرم
            // ═══════════════════════════════════════
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFB71C1C),
                        Color(0xFFE53935),
                        Color(0xFFFF7043),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: 1.0 + (_pulseController.value * 0.1),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.4),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.emergency_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'فریاکەوتن 🚑',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'ژمارەکانی گرنگ بۆ کەلار',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════
            // 🏷️ فلتری کەرت
            // ═══════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildCategoryFilter(isDark),
              ),
            ),

            // ═══════════════════════════════════════
            // 📋 لیستی خزمەتگوزارییەکان
            // ═══════════════════════════════════════
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child:
                  CircularProgressIndicator(color: Color(0xFFEF4444)),
                ),
              )
            else if (_filteredServices.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EmergencyCard(
                        service: _filteredServices[i],
                      ),
                    ),
                    childCount: _filteredServices.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    // ✅ لیستی تەواو بە String
    final List<Map<String, String>> categories = [
      {'key': 'all', 'label': 'هەموو'},
      {'key': 'police', 'label': 'پۆلیس'},
      {'key': 'fire', 'label': 'ئاگرکوژێنەوە'},
      {'key': 'ambulance', 'label': 'ئەمبولانس'},
      {'key': 'hospital', 'label': 'نەخۆشخانە'},
      {'key': 'utility', 'label': 'خزمەتگوزاری'},
    ];

    // ✅ نەخشەی ئایکۆنەکان
    final Map<String, IconData> iconMap = {
      'all': Icons.apps_rounded,
      'police': Icons.local_police_rounded,
      'fire': Icons.local_fire_department_rounded,
      'ambulance': Icons.local_hospital_rounded,
      'hospital': Icons.medical_services_rounded,
      'utility': Icons.build_rounded,
    };

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final catKey = cat['key']!;
          final catLabel = cat['label']!;
          final isSelected = _selectedCategory == catKey;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = catKey),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                  )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFE53935)
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      iconMap[catKey] ?? Icons.emergency_rounded,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                          ? Colors.white70
                          : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      catLabel,
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_outlined,
              size: 60,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ خزمەتگوزارییەک نییە',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}