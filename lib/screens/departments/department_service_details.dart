import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/settings_provider.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/service_details_widgets.dart';
import '../../l10n/tr.dart';

/// 📄 وردەکاری مامەڵەی فەرمانگە — ULTRA PRO
///
/// ✅ چاکسازی: بەکارهێنانی `ServiceDetailWidgets` ی هاوبەش
class DepartmentServiceDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> service;
  final Map<String, dynamic> department;

  const DepartmentServiceDetailsScreen({
    super.key,
    required this.service,
    required this.department,
  });

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color get _color => ServiceDetailWidgets.hexToColor(
    (service['color'] ?? department['color'] ?? '#10B981')
        .toString(),
    fallback: const Color(0xFF0F9D7A),
  );

  // ═══════════════════════════════════════════════════════════
  // 📊 Extract data
  // ═══════════════════════════════════════════════════════════
  String get _title => service['title_ku']?.toString() ?? '';
  String get _description => service['description']?.toString() ?? '';
  String get _duration => service['duration']?.toString() ?? '';
  String get _location => service['location']?.toString() ?? '';
  String get _notes => service['notes']?.toString() ?? '';
  String get _deptName =>
      department['name_ku']?.toString() ?? '';
  List<String> get _requirements =>
      _parseList(service['requirements']);
  List<String> get _fees => _parseList(service['fees']);

  // ═══════════════════════════════════════════════════════════
  // 🔧 Helpers
  // ═══════════════════════════════════════════════════════════
  List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      try {
        final s = raw.replaceAll(RegExp(r'^\{|\}$'), '');
        return s
            .split(',')
            .map((e) => e.trim().replaceAll('"', ''))
            .where((e) => e.isNotEmpty)
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;
    final color = _color;

    return Directionality(
      textDirection:
      lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══ 🎨 هێدەر ═══
            _buildHeader(color, isDark, lang),

            // ═══ 📊 ناوەڕۆک ═══
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ 📄 وەسف ═══
                    if (_description.isNotEmpty) ...[
                      _buildDescriptionCard(isDark, color, lang),
                      const SizedBox(height: 14),
                    ],

                    // ═══ 📄 پێداویستییەکان ═══
                    if (_requirements.isNotEmpty) ...[
                      _buildRequirementsCard(isDark, lang),
                      const SizedBox(height: 14),
                    ],

                    // ═══ 💰 تێچووەکان ═══
                    if (_fees.isNotEmpty) ...[
                      _buildFeesCard(isDark, lang),
                      const SizedBox(height: 14),
                    ],

                    // ═══ ℹ️ زانیاری زیاتر ═══
                    if (_hasExtraInfo) ...[
                      _buildExtraInfoCard(isDark, lang),
                      const SizedBox(height: 14),
                    ],

                    // ═══ 📝 تێبینی ═══
                    if (_notes.isNotEmpty) ...[
                      _buildNotesBox(isDark, lang),
                      const SizedBox(height: 20),
                    ],

                    // ═══ 📞 پەیوەندی ═══
                    _buildContactButton(context, isDark, lang),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
  bool get _hasDuration => _duration.isNotEmpty;
  bool get _hasLocation => _location.isNotEmpty;
  bool get _hasExtraInfo => _hasDuration || _hasLocation;

  // ═══════════════════════════════════════════════════════════
  // 🎨 Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(Color color, bool isDark, String lang) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, Color.lerp(color, Colors.black, 0.3)!],
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
                  if (_deptName.isNotEmpty) ...[
                    AutoTranslate(
                      text: _deptName,
                      lang: lang,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 6),
                  ],
                  AutoTranslate(
                    text: _title,
                    lang: lang,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 Description Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildDescriptionCard(
      bool isDark,
      Color color,
      String lang,
      ) {
    return _buildCard(
      isDark: isDark,
      color: color,
      icon: Icons.info_outline_rounded,
      title: tr('وەسف'),
      lang: lang,
      child: AutoTranslate(
        text: _description,
        lang: lang,
        style: TextStyle(
          fontSize: 13,
          height: 1.7,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        maxLines: 10,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 Requirements Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildRequirementsCard(bool isDark, String lang) {
    return _buildCard(
      isDark: isDark,
      color: const Color(0xFF4F5BD5),
      icon: Icons.checklist_rounded,
      title: tr('پێداویستییەکان'),
      lang: lang,
      badge: '${_requirements.length}',
      child: Column(
        children: _requirements.asMap().entries.map((e) {
          return ServiceDetailWidgets.buildRequirementItem(
            index: e.key + 1,
            text: e.value,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💰 Fees Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildFeesCard(bool isDark, String lang) {
    return _buildCard(
      isDark: isDark,
      color: const Color(0xFF0F9D7A),
      icon: Icons.attach_money_rounded,
      title: tr('تێچووەکان'),
      lang: lang,
      badge: '${_fees.length}',
      child: Column(
        children: _fees.asMap().entries.map((e) {
          return ServiceDetailWidgets.buildFeeItem(
            text: e.value,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ℹ️ Extra Info Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildExtraInfoCard(bool isDark, String lang) {
    return _buildCard(
      isDark: isDark,
      color: const Color(0xFFD9822B),
      icon: Icons.info_rounded,
      title: tr('زانیاری زیاتر'),
      lang: lang,
      child: Column(
        children: [
          if (_hasDuration)
            ServiceDetailWidgets.buildInfoRow(
              icon: Icons.access_time_rounded,
              label: tr('ماوەی مامەڵە'),
              value: _duration,
              color: const Color(0xFFD9822B),
              isDark: isDark,
            ),
          if (_hasDuration && _hasLocation)
            const SizedBox(height: 8),
          if (_hasLocation)
            ServiceDetailWidgets.buildInfoRow(
              icon: Icons.location_on_rounded,
              label: tr('شوێنی مامەڵە'),
              value: _location,
              color: const Color(0xFFDC3545),
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Notes Box
  // ═══════════════════════════════════════════════════════════
  Widget _buildNotesBox(bool isDark, String lang) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD9822B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD9822B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: Color(0xFFD9822B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AutoTranslate(
              text: _notes,
              lang: lang,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFD9822B),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              maxLines: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📞 Contact Button
  // ═══════════════════════════════════════════════════════════
  Widget _buildContactButton(
      BuildContext context,
      bool isDark,
      String lang,
      ) {
    final phone = department['phone']?.toString() ?? '';
    if (phone.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF4F5BD5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();
            final uri = Uri(scheme: 'tel', path: phone);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.call_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                AutoTranslate(
                  text: tr('پەیوەندی بە فەرمانگە'),
                  lang: lang,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Generic Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildCard({
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
    required String lang,
    String? badge,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
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
                  maxLines: 1,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr(badge),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}