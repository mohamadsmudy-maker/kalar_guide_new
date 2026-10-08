import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

/// 🎯 ئەنجامی فلتەر
class FilterResult {
  final String sortBy;
  final DateTime fromDate;
  final DateTime toDate;
  final String? authority;
  final Set<String> statuses;
  final bool onlyWithVoice;
  final bool onlyWithImages;

  FilterResult({
    required this.sortBy,
    required this.fromDate,
    required this.toDate,
    required this.authority,
    required this.statuses,
    required this.onlyWithVoice,
    required this.onlyWithImages,
  });
}

/// 🎯 Bottom Sheet ی فلتەرکردن
class ComplaintFilterSheet extends StatefulWidget {
  final String initialSortBy;
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final String? initialAuthority;
  final Set<String> initialStatuses;
  final bool onlyWithVoice;
  final bool onlyWithImages;
  final List<Map<String, dynamic>> complaints;
  final Function(FilterResult) onApply;

  const ComplaintFilterSheet({
    super.key,
    required this.initialSortBy,
    required this.initialFromDate,
    required this.initialToDate,
    required this.initialAuthority,
    required this.initialStatuses,
    required this.onlyWithVoice,
    required this.onlyWithImages,
    required this.complaints,
    required this.onApply,
  });

  @override
  State<ComplaintFilterSheet> createState() => _ComplaintFilterSheetState();
}

class _ComplaintFilterSheetState extends State<ComplaintFilterSheet> {
  late String _sortBy;
  late DateTime _fromDate;
  late DateTime _toDate;
  String? _authority;
  late Set<String> _statuses;
  late bool _onlyWithVoice;
  late bool _onlyWithImages;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialSortBy;
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
    _authority = widget.initialAuthority;
    _statuses = Set.from(widget.initialStatuses);
    _onlyWithVoice = widget.onlyWithVoice;
    _onlyWithImages = widget.onlyWithImages;
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      locale: const Locale('ar', 'AE'),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  Set<String> get _authorities {
    return widget.complaints
        .map((c) => c['responsible_authority']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'فلتەرکردن و ڕیزبەندکردن',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ═══ ڕیزبەندکردن ═══
                  _buildSection('ڕیزبەندکردن', Icons.sort_rounded),
                  const SizedBox(height: 8),
                  _buildSortOption(
                    'گرنگترین',
                    'priority',
                    Icons.priority_high_rounded,
                    'بەپێی گرنگی و دۆخ',
                  ),
                  _buildSortOption(
                    'نوێترین',
                    'newest',
                    Icons.access_time_rounded,
                    'دوایین سکاڵاکان',
                  ),
                  _buildSortOption(
                    'کۆنترین',
                    'oldest',
                    Icons.history_rounded,
                    'کۆنترین سکاڵاکان',
                  ),

                  const SizedBox(height: 20),

                  // ═══ بەروار ═══
                  _buildSection('ماوەی بەروار', Icons.date_range_rounded),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF0F1421),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_formatDate(_fromDate)} بۆ ${_formatDate(_toDate)}',
                              style: const TextStyle(
                                color: Color(0xFF0F1421),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF0F1421),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ═══ دۆخ ═══
                  _buildSection('دۆخ', Icons.checklist_rounded),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip('pending', 'چاوەڕوان'),
                      _buildStatusChip('in_progress', 'لە ئارادایە'),
                      _buildStatusChip('completed', 'تەواو'),
                      _buildStatusChip('rejected', 'ڕەتکراو'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ═══ لایەنی پەیوەندیدار ═══
                  _buildSection('لایەنی پەیوەندیدار', Icons.account_balance_rounded),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _authority,
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('هەموو لایەنەکان', style: TextStyle(fontSize: 13)),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('هەموو لایەنەکان', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                          ..._authorities.map(
                                (a) => DropdownMenuItem(
                              value: a,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(a, style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _authority = v),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ═══ فلتەرە زیادەکان ═══
                  _buildSection('فلتەرە زیادەکان', Icons.filter_alt_rounded),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _onlyWithVoice,
                    onChanged: (v) => setState(() => _onlyWithVoice = v),
                    title: const Text(
                      'تەنها دەنگ هەیە',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    secondary: const Icon(Icons.mic_rounded, color: Color(0xFF1E88E5)),
                  ),
                  SwitchListTile(
                    value: _onlyWithImages,
                    onChanged: (v) => setState(() => _onlyWithImages = v),
                    title: const Text(
                      'تەنها وێنە هەیە',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    secondary: const Icon(Icons.image_rounded, color: Color(0xFFE91E63)),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _sortBy = 'newest';
                            _fromDate = DateTime.now().subtract(const Duration(days: 30));
                            _toDate = DateTime.now();
                            _authority = null;
                            _statuses.clear();
                            _onlyWithVoice = false;
                            _onlyWithImages = false;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('پاککردنەوە'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onApply(FilterResult(
                            sortBy: _sortBy,
                            fromDate: _fromDate,
                            toDate: _toDate,
                            authority: _authority,
                            statuses: _statuses,
                            onlyWithVoice: _onlyWithVoice,
                            onlyWithImages: _onlyWithImages,
                          ));
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'جێبەجێکردن',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildSortOption(
      String label,
      String value,
      IconData icon,
      String subtitle,
      ) {
    final isSelected = _sortBy == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final isSelected = _statuses.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _statuses.remove(value);
          } else {
            _statuses.add(value);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
}