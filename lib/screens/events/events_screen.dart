import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/events/event_card.dart';
import 'event_details_screen.dart';

/// 📅 شاشەی ڕووداوەکان — ULTRA PRO
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  List<AppEvent> _allEvents = [];
  String _selectedCategory = 'all';

  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  final _categories = const [
    {'key': 'all', 'label': 'هەموو', 'label_ar': 'الكل', 'label_en': 'All'},
    {'key': 'national', 'label': '🇮🇶 نیشتمانی', 'label_ar': '🇮🇶 وطني', 'label_en': '🇮🇶 National'},
    {'key': 'religious', 'label': '🕌 ئاینی', 'label_ar': '🕌 ديني', 'label_en': '🕌 Religious'},
    {'key': 'sports', 'label': '⚽ وەرزشی', 'label_ar': '⚽ رياضي', 'label_en': '⚽ Sports'},
    {'key': 'cultural', 'label': '📚 کلتوری', 'label_ar': '📚 ثقافي', 'label_en': '📚 Cultural'},
  ];

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
    _loadData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final events = await EventService.getUpcoming(days: 90);
    if (mounted) {
      setState(() {
        _allEvents = events;
        _loading = false;
      });
      _entryController.forward(from: 0);
    }
  }

  List<AppEvent> get _filtered {
    if (_selectedCategory == 'all') return _allEvents;
    return _allEvents.where((e) => e.category == _selectedCategory).toList();
  }

  String _getCategoryLabel(Map<String, String> cat, String lang) {
    switch (lang) {
      case 'ar':
        return cat['label_ar'] ?? cat['label']!;
      case 'en':
        return cat['label_en'] ?? cat['label']!;
      default:
        return cat['label']!;
    }
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
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark, lang),
            SliverToBoxAdapter(child: _buildCategoryFilter(isDark, lang)),
            _loading
                ? const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6C5CE7),
                ),
              ),
            )
                : _filtered.isEmpty
                ? SliverFillRemaining(
              child: _buildEmptyState(isDark, lang),
            )
                : SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) => AnimatedBuilder(
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
                    child: EventCard(
                      event: _filtered[i],
                      onTap: () async {
                        await EventService.incrementViews(
                          _filtered[i].id!,
                        );
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailsScreen(
                              event: _filtered[i],
                            ),
                          ),
                        );
                      },
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
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(0xFF6C5CE7),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          lang == 'en'
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.event_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AutoTranslate(
                          text: 'ڕووداوەکان 📅',
                          lang: lang,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        AutoTranslate(
                          text: '${_allEvents.length} ڕووداوی داهاتوو',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark, String lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['key'];

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat['key']!);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
                  )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6C5CE7)
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getCategoryLabel(
                      Map<String, String>.from(cat),
                      lang,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 60,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 16),
          AutoTranslate(
            text: 'هیچ ڕووداوێکی داهاتوو نییە',
            lang: lang,
            style: TextStyle(
              fontSize: 15,
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