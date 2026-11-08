import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/settings_provider.dart';
import '../../widgets/common/auto_translate.dart';
import 'department_service_details.dart';
import '../../l10n/tr.dart';

/// 📋 مامەڵەکانی فەرمانگە — ULTRA PRO
class DepartmentServicesScreen extends StatefulWidget {
  final Map<String, dynamic> department;

  const DepartmentServicesScreen({super.key, required this.department});

  @override
  State<DepartmentServicesScreen> createState() =>
      _DepartmentServicesScreenState();
}

class _DepartmentServicesScreenState extends State<DepartmentServicesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('department_services')
          .select()
          .eq('department_id', widget.department['id'])
          .eq('is_active', true)
          .order('display_order');

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Services error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _deptColor {
    try {
      String hex = (widget.department['color'] ?? '#10B981')
          .toString()
          .replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF0F9D7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final name = widget.department['name_ku']?.toString() ?? 'فەرمانگە';
    final color = _deptColor;

    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.3)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.description_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AutoTranslate(
                            text: name,
                            lang: lang,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          AutoTranslate(
                            text: trf('{0} مامەڵە بەردەستە', [_services.length]),
                            lang: lang,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _loading
                ? const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0F9D7A),
                ),
              ),
            )
                : _services.isEmpty
                ? SliverFillRemaining(
              child: _buildEmpty(isDark, color, lang),
            )
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildServiceCard(
                    _services[i],
                    isDark,
                    color,
                    i,
                    lang,
                  ),
                  childCount: _services.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
      Map<String, dynamic> service,
      bool isDark,
      Color color,
      int index,
      String lang,
      ) {
    final title = service['title_ku']?.toString() ?? '';
    final description = service['description']?.toString() ?? '';
    final duration = service['duration']?.toString() ?? '';
    final requirements = service['requirements'];
    final fees = service['fees'];

    final reqCount = requirements is List ? requirements.length : 0;
    final feeCount = fees is List ? fees.length : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DepartmentServiceDetailsScreen(
                  service: service,
                  department: widget.department,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                color: color.withValues(alpha: 0.2),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color,
                            Color.lerp(color, Colors.white, 0.3)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoTranslate(
                        text: title,
                        lang: lang,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        lang == 'en'
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.arrow_back_ios_rounded,
                        color: color,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  AutoTranslate(
                    text: description,
                    lang: lang,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (reqCount > 0)
                      _buildInfoBadge(
                        Icons.checklist_rounded,
                        trf('{0} پێداویستی', [reqCount]),
                        const Color(0xFF4F5BD5),
                        lang,
                      ),
                    if (feeCount > 0)
                      _buildInfoBadge(
                        Icons.attach_money_rounded,
                        trf('{0} تێچوو', [feeCount]),
                        const Color(0xFF0F9D7A),
                        lang,
                      ),
                    if (duration.isNotEmpty)
                      _buildInfoBadge(
                        Icons.access_time_rounded,
                        duration,
                        const Color(0xFFD9822B),
                        lang,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(
      IconData icon,
      String label,
      Color color,
      String lang,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          AutoTranslate(
            text: label,
            lang: lang,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark, Color color, String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 60,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          AutoTranslate(
            text: tr('هیچ مامەڵەیەک نییە'),
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