import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/event_service.dart';
import '../../widgets/events/event_card.dart';
import 'event_details_screen.dart';

class EventsScreen extends StatefulWidget {  // ✅
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;
  List<AppEvent> _allEvents = [];
  String _selectedCategory = 'all';

  final _categories = const [
    {'key': 'all', 'label': 'هەموو'},
    {'key': 'national', 'label': '🇮🇶 نیشتمانی'},
    {'key': 'religious', 'label': '🕌 ئاینی'},
    {'key': 'sports', 'label': '⚽ وەرزشی'},
    {'key': 'cultural', 'label': '📚 کلتوری'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final events = await EventService.getUpcoming(days: 90);
    if (mounted) {
      setState(() {
        _allEvents = events;
        _loading = false;
      });
    }
  }

  List<AppEvent> get _filtered {
    if (_selectedCategory == 'all') return _allEvents;
    return _allEvents.where((e) => e.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
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
                            child: const Icon(Icons.event_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('ڕووداوەکان 📅',
                                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text('${_allEvents.length} ڕووداوی داهاتوو',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
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
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat['key']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)]) : null,
                            color: isSelected ? null : (isDark ? const Color(0xFF1A1A22) : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF6C5CE7) : (isDark ? Colors.white24 : Colors.grey.shade300),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(cat['label']!,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700))),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) => EventCard(
                      event: _filtered[i],
                      onTap: () async {
                        await EventService.incrementViews(_filtered[i].id!);
                        if (!context.mounted) return;
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => EventDetailsScreen(event: _filtered[i])));
                      },
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

  Widget _buildEmptyState(bool isDark) {
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
            child: const Icon(Icons.event_busy_rounded, size: 60, color: Color(0xFF6C5CE7)),
          ),
          const SizedBox(height: 16),
          Text('هیچ ڕووداوێکی داهاتوو نییە',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        ],
      ),
    );
  }
}