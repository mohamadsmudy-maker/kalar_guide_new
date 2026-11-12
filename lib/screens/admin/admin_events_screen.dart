import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../l10n/tr.dart';

/// 📅 شاشەی بەڕێوەبردنی ڕووداوەکان
class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<AppEvent> _upcoming = [];
  List<AppEvent> _past = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی داتا — ✅ بێ Future.wait
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      // ⭐ ١. ڕووداوەکانی داهاتوو
      final upcoming = await EventService.getUpcoming(days: 365);

      // ⭐ ٢. ڕووداوەکانی ڕابردوو
      final now = DateTime.now().toIso8601String();
      final pastRes = await Supabase.instance.client
          .from('events')
          .select()
          .lt('start_date', now)
          .order('start_date', ascending: false)
          .limit(50);

      // ✅ Cast بە تەواوی
      final pastList = (pastRes as List)
          .map((e) => AppEvent.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();

      if (mounted) {
        setState(() {
          _upcoming = upcoming;
          _past = pastList;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕✏️ زیادکردن / دەستکاریکردن
  // ═══════════════════════════════════════════════════════════
  Future<void> _openEditor({AppEvent? event}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EventEditorDialog(event: event),
    );

    if (result == null) return;

    try {
      if (event == null) {
        // ✅ زیادکردن
        await EventService.addEvent(result);
      } else if (event.id != null) {
        // ✅ دەستکاریکردن
        await EventService.updateEvent(event.id!, result);
      }
      if (mounted) _loadData();
    } catch (e) {
      debugPrint('❌ _openEditor error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteEvent(AppEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(tr('سڕینەوە')),
          content:
              Text(trf('ئایا دڵنیایت لە سڕینەوەی "{0}"؟', [event.titleKu])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && event.id != null) {
      await EventService.deleteEvent(event.id!);
      if (mounted) _loadData();
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
        body: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFF4F5BD5),
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF4F5BD5),
                        Color(0xFFC2557A),
                      ],
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
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  tr('بەڕێوەبردنی ڕووداوەکان 📅'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelColor: const Color(0xFF4F5BD5),
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    tabs: [
                      Tab(text: trf('داهاتوو ({0})', [_upcoming.length])),
                      Tab(text: trf('ڕابردوو ({0})', [_past.length])),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4F5BD5),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_upcoming, isUpcoming: true),
                    _buildList(_past, isUpcoming: false),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: const Color(0xFF4F5BD5),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            tr('ڕووداوی نوێ'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 لیست
  // ═══════════════════════════════════════════════════════════
  Widget _buildList(List<AppEvent> list, {required bool isUpcoming}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming
                  ? Icons.event_available_rounded
                  : Icons.event_busy_rounded,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              tr(isUpcoming
                  ? 'هیچ ڕووداوێکی داهاتوو نییە'
                  : 'هیچ ڕووداوی ڕابردوو نییە'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      // ✅ تەنها 1 پارامەتر
      itemBuilder: (ctx, i) => _buildCard(list[i]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارت — ✅ تەنها 1 پارامەتر
  // ═══════════════════════════════════════════════════════════
  Widget _buildCard(AppEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    try {
      String hex = event.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      color = Color(int.parse(hex, radix: 16));
    } catch (_) {
      color = const Color(0xFF4F5BD5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                event.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: color.withValues(alpha: 0.2),
                  child: Icon(Icons.event_rounded, color: color, size: 50),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tr(_getCategoryLabel(event.category)),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    if (event.isFeatured) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9822B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              tr('تایبەت'),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Color(0xFF1E88E5),
                            size: 20,
                          ),
                          onPressed: () => _openEditor(event: event),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFDC3545),
                            size: 20,
                          ),
                          onPressed: () => _deleteEvent(event),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  tr(event.titleKu),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr(event.getFormattedDate()),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (event.locationName != null &&
                    event.locationName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: Color(0xFFDC3545),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tr(event.locationName!),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    switch (cat) {
      case 'national':
        return '🇮🇶 نیشتمانی';
      case 'religious':
        return '🕌 ئاینی';
      case 'sports':
        return '⚽ وەرزشی';
      case 'cultural':
        return '📚 کلتوری';
      default:
        return '📅 ڕووداو';
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی ڕووداو
// ═══════════════════════════════════════════════════════════
class _EventEditorDialog extends StatefulWidget {
  final AppEvent? event;

  const _EventEditorDialog({this.event});

  @override
  State<_EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<_EventEditorDialog> {
  late TextEditingController _titleKuCtrl;
  late TextEditingController _titleArCtrl;
  late TextEditingController _titleEnCtrl;
  late TextEditingController _descKuCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _organizerCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _imageUrlCtrl;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  DateTime? _endDate;
  late String _category;
  late String _selectedColor;
  bool _isFeatured = false;
  bool _isAllDay = false;
  bool _loading = false;

  final _categories = [
    {'key': 'national', 'label': '🇮🇶 نیشتمانی'},
    {'key': 'religious', 'label': '🕌 ئاینی'},
    {'key': 'sports', 'label': '⚽ وەرزشی'},
    {'key': 'cultural', 'label': '📚 کلتوری'},
    {'key': 'general', 'label': '📅 گشتی'},
  ];

  final _colors = [
    '#6C5CE7',
    '#E91E63',
    '#10B981',
    '#1E88E5',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
    '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.event;

    _titleKuCtrl = TextEditingController(text: e?.titleKu ?? '');
    _titleArCtrl = TextEditingController(text: e?.titleAr ?? '');
    _titleEnCtrl = TextEditingController(text: e?.titleEn ?? '');
    _descKuCtrl = TextEditingController(text: e?.descriptionKu ?? '');
    _locationCtrl = TextEditingController(text: e?.locationName ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _organizerCtrl = TextEditingController(text: e?.organizer ?? '');
    _phoneCtrl = TextEditingController(text: e?.contactPhone ?? '');
    _imageUrlCtrl = TextEditingController(text: e?.imageUrl ?? '');

    _startDate = e?.startDate ?? DateTime.now().add(const Duration(days: 1));
    _startTime = TimeOfDay(
      hour: e?.startDate.hour ?? 10,
      minute: e?.startDate.minute ?? 0,
    );
    _endDate = e?.endDate;
    _category = e?.category ?? 'general';
    _selectedColor = e?.color ?? '#6C5CE7';
    _isFeatured = e?.isFeatured ?? false;
    _isAllDay = e?.isAllDay ?? false;
  }

  @override
  void dispose() {
    _titleKuCtrl.dispose();
    _titleArCtrl.dispose();
    _titleEnCtrl.dispose();
    _descKuCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _organizerCtrl.dispose();
    _phoneCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('ar', 'AE'),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _save() async {
    if (_titleKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('ناونیشان پێویستە')),
          backgroundColor: const Color(0xFFD9822B),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final user = AuthSessionManager.currentUser;

      // ✅ Map ی پارێزراو بە type
      final Map<String, dynamic> data = {
        'title_ku': _titleKuCtrl.text.trim(),
        'title_ar':
            _titleArCtrl.text.trim().isEmpty ? null : _titleArCtrl.text.trim(),
        'title_en':
            _titleEnCtrl.text.trim().isEmpty ? null : _titleEnCtrl.text.trim(),
        'description_ku':
            _descKuCtrl.text.trim().isEmpty ? null : _descKuCtrl.text.trim(),
        'start_date': startDateTime.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'is_all_day': _isAllDay,
        'location_name': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'organizer': _organizerCtrl.text.trim().isEmpty
            ? null
            : _organizerCtrl.text.trim(),
        'contact_phone':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim().isEmpty
            ? null
            : _imageUrlCtrl.text.trim(),
        'category': _category,
        'color': _selectedColor,
        'is_featured': _isFeatured,
        'is_published': true,
        'created_by': user?['id']?.toString(),
      };

      if (mounted) Navigator.pop(context, data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;

    return Directionality(
      textDirection: AppLang.direction,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      color: Color(0xFF4F5BD5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr(isEditing ? 'دەستکاریکردنی ڕووداو' : 'ڕووداوی نوێ'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 🏷️ کەرت
                Text(
                  tr('کەرت'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final isSelected = _category == c['key'];
                    return GestureDetector(
                      onTap: () => setState(() => _category = c['key']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF4F5BD5),
                                    Color(0xFFC2557A),
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4F5BD5)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          tr(c['label']!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                _buildField(tr('ناونیشانی کوردی *'), _titleKuCtrl),
                const SizedBox(height: 10),
                _buildField(tr('ناونیشانی عەرەبی'), _titleArCtrl),
                const SizedBox(height: 10),
                _buildField(tr('ناونیشانی ئینگلیزی'), _titleEnCtrl),
                const SizedBox(height: 10),
                _buildField(tr('وەسف'), _descKuCtrl, maxLines: 3),
                const SizedBox(height: 16),

                // 📅 بەروار و کات
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF4F5BD5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4F5BD5)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF4F5BD5),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_startDate.year}/${_startDate.month}/${_startDate.day}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4F5BD5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isAllDay ? null : _pickTime,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isAllDay
                                ? Colors.grey.shade100
                                : const Color(0xFF4F5BD5)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isAllDay
                                  ? Colors.grey.shade300
                                  : const Color(0xFF4F5BD5)
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: _isAllDay
                                    ? Colors.grey
                                    : const Color(0xFF4F5BD5),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr(_isAllDay
                                    ? 'هەموو ڕۆژ'
                                    : '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _isAllDay
                                      ? Colors.grey
                                      : const Color(0xFF4F5BD5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                SwitchListTile(
                  value: _isAllDay,
                  onChanged: (v) => setState(() => _isAllDay = v),
                  title: Text(
                    tr('هەموو ڕۆژ'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 10),
                _buildField(tr('شوێن'), _locationCtrl),
                const SizedBox(height: 10),
                _buildField(tr('ناونیشان'), _addressCtrl),
                const SizedBox(height: 10),
                _buildField(tr('ڕێکخەر'), _organizerCtrl),
                const SizedBox(height: 10),
                _buildField(
                  tr('ژمارەی پەیوەندی'),
                  _phoneCtrl,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _buildField(tr('لینکی وێنە (URL)'), _imageUrlCtrl),
                const SizedBox(height: 16),

                // 🎨 ڕەنگ
                Text(
                  tr('ڕەنگ'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((c) {
                    Color color;
                    try {
                      String hex = c.replaceAll('#', '');
                      if (hex.length == 6) hex = 'FF$hex';
                      color = Color(int.parse(hex, radix: 16));
                    } catch (_) {
                      color = const Color(0xFF4F5BD5);
                    }
                    final isSelected = _selectedColor == c;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                  title: Text(
                    tr('ڕووداوی تایبەت ⭐'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  secondary: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFD9822B),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F5BD5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            tr(isEditing ? 'نوێکردنەوە' : 'بڵاوکردنەوە'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}
