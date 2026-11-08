import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/theme_provider.dart';
import '../../l10n/tr.dart';

/// ⚙️ شاشەی ڕێکخستن — ULTRA PRO MAX V2
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  bool _savedVisible = false;
  Timer? _savedTimer;

  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _entryController.value = 1;
      _pulseController
        ..stop()
        ..value = 0.5;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _entryController.dispose();
    _pulseController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Helpers ─────────────────────────

  void _apply(VoidCallback change) {
    change();
    _savedTimer?.cancel();
    setState(() => _savedVisible = true);
    _savedTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _savedVisible = false);
    });
  }

  bool _matches(_SectionDef s) {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return true;
    return s.title.toLowerCase().contains(q) ||
        s.keywords.toLowerCase().contains(q);
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = _Pal(isDark);
    final settings = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final sections = <_SectionDef>[
      _languageSection(pal, settings),
      _fontSection(pal, settings),
      _fontSizeSection(pal, settings),
      _previewSection(pal, settings),
      _themeSection(pal, themeProvider),
      _notificationSection(pal, settings),
    ].where(_matches).toList();

    var i = 1;
    Widget reveal(Widget w, {Axis axis = Axis.horizontal}) =>
        _Reveal(animation: _entryController, index: i++, axis: axis, child: w);

    final children = <Widget>[
      reveal(_buildQuickInfo(pal), axis: Axis.vertical),
      const SizedBox(height: 20),
      _buildSearchBar(pal),
      const SizedBox(height: 20),
    ];

    if (sections.isEmpty) {
      children.add(_buildEmptyState(pal));
    }

    for (final section in sections) {
      children
        ..add(reveal(_buildSectionTitle(section.title, pal)))
        ..add(const SizedBox(height: 12))
        ..addAll(section.items.map(reveal))
        ..add(const SizedBox(height: 20));
    }

    if (_searchQuery.isEmpty) {
      children.add(
        reveal(_buildResetButton(pal, settings), axis: Axis.vertical),
      );
    }
    children.add(const SizedBox(height: 30));

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: pal.bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            _buildAppBar(pal),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Sections ─────────────────────────

  _SectionDef _languageSection(_Pal pal, SettingsProvider settings) {
    return _SectionDef(
      title: tr('🌍 زمان'),
      keywords: 'زمان language کوردی عەرەبی english',
      items: SettingsProvider.availableLanguages.map((lang) {
        final selected = settings.languageId == lang.id;
        return _SelectTile(
          pal: pal,
          selected: selected,
          leading: Text(tr(lang.flag), style: const TextStyle(fontSize: 26)),
          title: lang.name,
          subtitle: lang.native,
          trailing: _RadioDot(selected: selected, isDark: pal.isDark),
          onTap: () => _apply(() => settings.setLanguage(lang.id)),
        );
      }).toList(),
    );
  }

  _SectionDef _fontSection(_Pal pal, SettingsProvider settings) {
    return _SectionDef(
      title: tr('🔤 جۆری فۆنت'),
      keywords: 'فۆنت font typeface',
      items: [
        Container(
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: settings.fontId,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: BorderRadius.circular(14),
              dropdownColor: pal.surface,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
              items: SettingsProvider.availableFonts.map((font) {
                return DropdownMenuItem<String>(
                  value: font.id,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.text_fields_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr(font.name),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: pal.text,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                HapticFeedback.selectionClick();
                _apply(() => settings.setFont(value));
              },
            ),
          ),
        ),
      ],
    );
  }

  _SectionDef _fontSizeSection(_Pal pal, SettingsProvider settings) {
    return _SectionDef(
      title: tr('📏 قەبارەی فۆنت'),
      keywords: 'قەبارە size scale گەورە بچووک',
      items: SettingsProvider.availableFontSizes.map((size) {
        final selected = settings.fontSizeId == size.id;
        return _SelectTile(
          pal: pal,
          selected: selected,
          leading: _RadioDot(selected: selected, isDark: pal.isDark),
          title: size.name,
          trailing: Text(
            'Aa',
            style: TextStyle(
              fontSize: 16 * size.scale,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : Colors.grey,
            ),
          ),
          onTap: () => _apply(() => settings.setFontSize(size.id)),
        );
      }).toList(),
    );
  }

  _SectionDef _previewSection(_Pal pal, SettingsProvider settings) {
    return _SectionDef(
      title: tr('👁️ پێشبینین'),
      keywords: 'پێشبینین preview نموونە',
      items: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ناونیشان — Title'),
                  style: TextStyle(
                    fontSize: 20 * settings.fontScale,
                    fontWeight: FontWeight.bold,
                    color: pal.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('ژێرناونیشان — Subtitle'),
                  style: TextStyle(
                    fontSize: 15 * settings.fontScale,
                    fontWeight: FontWeight.w600,
                    color: pal.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('ئەمە نموونەیەکی نووسینە بۆ پیشاندانی فۆنت و قەبارەکەت. دەتوانیت هەموو شتێک بە ئاسانی بگۆڕیت.'),
                  style: TextStyle(
                    fontSize: 13 * settings.fontScale,
                    color: pal.isDark ? Colors.white60 : Colors.black54,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _SectionDef _themeSection(_Pal pal, ThemeProvider themeProvider) {
    Widget option({
      required ThemeMode mode,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
    }) {
      final selected = themeProvider.themeMode == mode;
      return _SelectTile(
        pal: pal,
        selected: selected,
        leading: _IconBadge(icon: icon, color: color),
        title: title,
        subtitle: subtitle,
        trailing: _RadioDot(selected: selected, isDark: pal.isDark),
        onTap: () => _apply(() => themeProvider.setThemeMode(mode)),
      );
    }

    return _SectionDef(
      title: tr('🌙 ڕەنگی ئەپ'),
      keywords: 'ڕەنگ theme تاریک ڕووناک سیستەم dark light system',
      items: [
        option(
          mode: ThemeMode.light,
          icon: Icons.light_mode_rounded,
          title: tr('ڕووناک'),
          subtitle: 'Light',
          color: Colors.orange,
        ),
        option(
          mode: ThemeMode.dark,
          icon: Icons.dark_mode_rounded,
          title: tr('تاریک'),
          subtitle: 'Dark',
          color: Colors.purple,
        ),
        option(
          mode: ThemeMode.system,
          icon: Icons.settings_brightness_rounded,
          title: tr('سیستەم'),
          subtitle: 'System',
          color: Colors.blue,
        ),
      ],
    );
  }

  _SectionDef _notificationSection(_Pal pal, SettingsProvider settings) {
    final master = settings.notificationsEnabled;

    Widget sw({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required bool value,
      required ValueChanged<bool> onChanged,
      bool dependsOnMaster = true,
    }) {
      return _SwitchTile(
        pal: pal,
        icon: icon,
        title: title,
        subtitle: subtitle,
        color: color,
        value: value,
        enabled: dependsOnMaster ? master : true,
        onChanged: (v) => _apply(() => onChanged(v)),
      );
    }

    return _SectionDef(
      title: tr('🔔 ئاگادارکردنەوە'),
      keywords: 'ئاگادارکردنەوە notification هەواڵ سکاڵا داواکاری ئۆردەر '
          'دەنگ لەرینەوە news complaint order sound vibration',
      items: [
        sw(
          icon: Icons.notifications_active_rounded,
          title: tr('چالاککردنی ئاگادارکردنەوە'),
          subtitle: tr('هەموو ئاگادارکردنەوەکان'),
          color: AppColors.primary,
          value: master,
          dependsOnMaster: false,
          onChanged: settings.setNotificationsEnabled,
        ),
        sw(
          icon: Icons.newspaper_rounded,
          title: tr('هەواڵەکان'),
          subtitle: tr('ئاگادارکردنەوە بۆ هەواڵی نوێ'),
          color: Colors.blue,
          value: settings.newsNotifications,
          onChanged: settings.setNewsNotifications,
        ),
        sw(
          icon: Icons.report_rounded,
          title: tr('سکاڵاکان'),
          subtitle: tr('ئاگادارکردنەوە بۆ سکاڵاکانت'),
          color: Colors.red,
          value: settings.complaintNotifications,
          onChanged: settings.setComplaintNotifications,
        ),
        sw(
          icon: Icons.shopping_bag_rounded,
          title: tr('داواکارییەکان'),
          subtitle: tr('ئاگادارکردنەوە بۆ ئۆردەرەکانت'),
          color: Colors.green,
          value: settings.orderNotifications,
          onChanged: settings.setOrderNotifications,
        ),
        sw(
          icon: Icons.volume_up_rounded,
          title: tr('دەنگ'),
          subtitle: tr('دەنگی ئاگادارکردنەوە'),
          color: Colors.orange,
          value: settings.soundEnabled,
          onChanged: settings.setSoundEnabled,
        ),
        sw(
          icon: Icons.vibration_rounded,
          title: tr('لەرینەوە'),
          subtitle: tr('لەرینەوەی مۆبایل'),
          color: Colors.teal,
          value: settings.vibrationEnabled,
          onChanged: settings.setVibrationEnabled,
        ),
      ],
    );
  }

  // ───────────────────────── AppBar ─────────────────────────

  Widget _buildAppBar(_Pal pal) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: pal.surface,
      foregroundColor: pal.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [_buildSavedBadge()],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: pal.isDark
                  ? const [Color(0xFF1A1A22), Color(0xFF252530)]
                  : [
                Colors.white,
                AppColors.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    children: [
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                            child: child,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color.lerp(
                                      AppColors.primary, Colors.white, 0.2)!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr('ڕێکخستنەکان'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: pal.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('زمان، فۆنت، ڕەنگ، ئاگادارکردنەوە'),
                              style: TextStyle(
                                fontSize: 12,
                                color: pal.subText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedBadge() {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: _savedVisible ? tr('پاشەکەوت کرا') : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _savedVisible ? 1 : 0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              scale: _savedVisible ? 1 : 0.8,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _Pal.success,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _Pal.success.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      tr('پاشەکەوت کرا'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Static widgets ─────────────────────────

  Widget _buildQuickInfo(_Pal pal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('ڕێکخستنەکان خۆکارانە پاشەکەوت دەکرێن'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: pal.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('هەر گۆڕانکارییەک دەستبەجێ پاشەکەوت دەکرێت'),
                  style: TextStyle(fontSize: 10, color: pal.subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(_Pal pal) {
    final active = _searchQuery.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.4)
              : (pal.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: TextStyle(
                color: pal.isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: tr('گەڕان بەدوای ڕێکخستن...'),
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: pal.isDark ? Colors.white38 : Colors.grey,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (active)
            IconButton(
              tooltip: tr('سڕینەوە'),
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: pal.isDark ? Colors.white54 : Colors.grey,
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, _Pal pal) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 6),
        child: Semantics(
          header: true,
          child: Text(
            tr(title),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: pal.isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(_Pal pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: pal.subText),
          const SizedBox(height: 12),
          Text(
            tr('هیچ ڕێکخستنێک نەدۆزرایەوە'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: pal.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('وشەیەکی تر تاقی بکەرەوە'),
            style: TextStyle(fontSize: 12, color: pal.subText),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Reset ─────────────────────────

  Widget _buildResetButton(_Pal pal, SettingsProvider settings) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: tr('گەڕاندنەوە بۆ دۆخی سەرەتا'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: pal.isDark ? 0.15 : 0.08),
          borderRadius: radius,
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.mediumImpact();
              _showResetDialog(settings);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const _IconBadge(
                    icon: Icons.restore_rounded,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('گەڕاندنەوە بۆ دۆخی سەرەتا'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showResetDialog(SettingsProvider settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('گەڕاندنەوە بۆ دۆخی سەرەتا'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            tr('ئایا دڵنیایت؟ هەموو ڕێکخستنەکان دەگەڕێنەوە بۆ دۆخی سەرەتا.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('پاشگەزبوونەوە')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                tr('بەڵێ، بیگەڕێنەوە'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await settings.resetToDefaults();
      if (!mounted) return;
      _savedTimer?.cancel();
      setState(() => _savedVisible = false);
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('✅ ڕێکخستنەکان گەڕێنرانەوە'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: _Pal.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('❌ نەتوانرا ڕێکخستنەکان بگەڕێنرێنەوە'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎨 Palette
// ═══════════════════════════════════════════════════════════════
class _Pal {
  final bool isDark;
  const _Pal(this.isDark);

  static const success = Color(0xFF10B981);

  Color get bg => isDark ? const Color(0xFF0F0F14) : const Color(0xFFF5F6FA);
  Color get surface => isDark ? const Color(0xFF1A1A22) : Colors.white;
  Color get border =>
      isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200;
  Color get text => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get subText => isDark ? Colors.white54 : Colors.grey.shade600;
}

// ═══════════════════════════════════════════════════════════════
// ✨ Reveal animation
// ═══════════════════════════════════════════════════════════════
class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Axis axis;
  final Widget child;

  const _Reveal({
    required this.animation,
    required this.index,
    required this.child,
    this.axis = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final delay = (index * 0.06).clamp(0.0, 0.6);
        final p = Curves.easeOutCubic
            .transform(((animation.value - delay) / 0.4).clamp(0.0, 1.0));
        final offset = axis == Axis.horizontal
            ? Offset(20 * (1 - p), 0)
            : Offset(0, 20 * (1 - p));
        return Transform.translate(
          offset: offset,
          child: Opacity(opacity: p, child: child),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🔘 Reusable tiles
// ═══════════════════════════════════════════════════════════════
class _RadioDot extends StatelessWidget {
  final bool selected;
  final bool isDark;
  const _RadioDot({required this.selected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.primary
              : (isDark ? Colors.white38 : Colors.grey),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SelectTile extends StatelessWidget {
  final _Pal pal;
  final bool selected;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SelectTile({
    required this.pal,
    required this.selected,
    required this.title,
    required this.onTap,
    this.leading,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.primary : pal.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(title),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: pal.text,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            tr(subtitle!),
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.subText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final _Pal pal;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.pal,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1.0 : 0.4,
      child: MergeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              _IconBadge(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(title),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pal.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(subtitle),
                      style: TextStyle(fontSize: 11, color: pal.subText),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: enabled
                    ? (v) {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                }
                    : null,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDef {
  final String title;
  final String keywords;
  final List<Widget> items;
  const _SectionDef({
    required this.title,
    required this.keywords,
    required this.items,
  });
}