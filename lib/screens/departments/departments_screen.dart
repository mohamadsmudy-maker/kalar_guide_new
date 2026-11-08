import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/settings_provider.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'department_services_screen.dart';
import '../../l10n/tr.dart';

/// 🏛️ لیستی فەرمانگەکان — ULTRA PRO
class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _departments = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _loadDepartments();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('departments')
          .select()
          .order('name_ku');

      if (mounted) {
        setState(() {
          _departments = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
        _entryController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ Departments error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _departments;
    final q = _searchQuery.toLowerCase();
    return _departments.where((d) {
      final name = (d['name_ku'] ?? '').toString().toLowerCase();
      final nameAr = (d['name_ar'] ?? '').toString().toLowerCase();
      return name.contains(q) || nameAr.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark, lang),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSearchBar(isDark, lang),
              ),
            ),
            _loading
                ? const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF10B981),
                ),
              ),
            )
                : _filtered.isEmpty
                ? SliverFillRemaining(child: _buildEmpty(isDark, lang))
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) => AnimatedBuilder(
                    animation: _entryAnimation,
                    builder: (context, child) {
                      final delay = (i * 0.06).clamp(0.0, 1.0);
                      final progress =
                      ((_entryAnimation.value - delay) / 0.5)
                          .clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - progress)),
                        child:
                        Opacity(opacity: progress, child: child),
                      );
                    },
                    child: _buildDepartmentCard(
                      _filtered[i],
                      isDark,
                      lang,
                      i,
                    ),
                  ),
                  childCount: _filtered.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, String lang) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 160,
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: isDark ? Colors.white : const Color(0xFF10B981),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0A0A0F), const Color(0xFF0D2818)]
                  : [const Color(0xFFF0F4F9), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color:
                          const Color(0xFF10B981).withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AutoTranslate(
                          text: tr('فەرمانگەکان'),
                          lang: lang,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        AutoTranslate(
                          text: trf('{0} فەرمانگە بەردەستن', [_departments.length]),
                          lang: lang,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, String lang) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF10B981),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: lang == 'ar'
                    ? tr('ابحث عن الدوائر...')
                    : (lang == 'en'
                    ? 'Search departments...'
                    : 'گەڕان بەدوای فەرمانگەکان...'),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(
      Map<String, dynamic> dept,
      bool isDark,
      String lang,
      int index,
      ) {
    final palettes = [
      [const Color(0xFF1E88E5), const Color(0xFF42A5F5)],
      [const Color(0xFFE91E63), const Color(0xFFF06292)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF14B8A6), const Color(0xFF2DD4BF)],
      [const Color(0xFFEF4444), const Color(0xFFF87171)],
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
    ];
    final palette = palettes[index % palettes.length];
    final primaryColor = palette[0];
    final secondaryColor = palette[1];

    final name = dept['name_ku']?.toString() ?? 'فەرمانگە';
    final image = dept['image']?.toString() ?? '';
    final hasImage = image.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DepartmentServicesScreen(department: dept),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A1A22), const Color(0xFF1F1F2A)]
                    : [Colors.white, const Color(0xFFFAFBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.2),
                        secondaryColor.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: hasImage
                        ? OptimizedNetworkImage(
                      imageUrl: image,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.25),
                            secondaryColor.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.business_rounded,
                        color: primaryColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoTranslate(
                        text: name,
                        lang: lang,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.description_rounded,
                                  size: 12,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 5),
                                AutoTranslate(
                                  text: tr('بینینی مامەڵەکان'),
                                  lang: lang,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    lang == 'en'
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark, String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_outlined,
              size: 60,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          AutoTranslate(
            text: tr('هیچ فەرمانگەیەک نییە'),
            lang: lang,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}