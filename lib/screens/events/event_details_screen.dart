import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../l10n/tr.dart';

class EventDetailsScreen extends StatefulWidget {
  final AppEvent event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isInterested = false;
  int _interestedCount = 0;

  Color get _color {
    try {
      String hex = widget.event.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF6C5CE7);
    }
  }

  @override
  void initState() {
    super.initState();
    _interestedCount = widget.event.interestedCount;
    _checkInterest();
  }

  Future<void> _checkInterest() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) return;
    final interested = await EventService.isInterested(
      eventId: widget.event.id!,
      userId: user['id']?.toString() ?? '',
    );
    if (mounted) setState(() => _isInterested = interested);
  }

  Future<void> _toggleInterest() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تکایە سەرەتا بچۆ ژوورەوە ⚠')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final wasInterested = _isInterested;
    setState(() {
      _isInterested = !wasInterested;
      _interestedCount = wasInterested
          ? (_interestedCount > 0 ? _interestedCount - 1 : 0)
          : _interestedCount + 1;
    });

    await EventService.toggleInterest(
      eventId: widget.event.id!,
      userId: user['id']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final e = widget.event;
    final color = _color;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: e.imageUrl != null && e.imageUrl!.isNotEmpty
                    ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      e.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildGradientBg(color),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                )
                    : _buildGradientBg(color),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══════════════════════════════════════
                    // 🏷️ کەرت + تایبەت
                    // ═══════════════════════════════════════
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tr(_getCategoryLabel(e.category)),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (e.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  tr('تایبەت'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ═══════════════════════════════════════
                    // 📌 ناونیشان
                    // ═══════════════════════════════════════
                    Text(
                      tr(e.titleKu),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color:
                        isDark ? Colors.white : const Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ═══════════════════════════════════════
                    // 📊 کارتی زانیاری
                    // ═══════════════════════════════════════
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                        isDark ? const Color(0xFF1A1A22) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.calendar_today_rounded,
                            'بەروار',
                            e.getFormattedDate(),
                            color,
                            isDark,
                          ),
                          const Divider(height: 20),
                          _buildInfoRow(
                            Icons.access_time_rounded,
                            'کات',
                            e.getFormattedTime(),
                            color,
                            isDark,
                          ),
                          if (e.locationName != null &&
                              e.locationName!.isNotEmpty) ...[
                            const Divider(height: 20),
                            _buildInfoRow(
                              Icons.location_on_rounded,
                              'شوێن',
                              e.locationName!,
                              color,
                              isDark,
                            ),
                          ],
                          if (e.organizer != null &&
                              e.organizer!.isNotEmpty) ...[
                            const Divider(height: 20),
                            _buildInfoRow(
                              Icons.business_rounded,
                              'ڕێکخەر',
                              e.organizer!,
                              color,
                              isDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ═══════════════════════════════════════
                    // 📄 وەسف
                    // ═══════════════════════════════════════
                    if (e.descriptionKu != null &&
                        e.descriptionKu!.isNotEmpty) ...[
                      Text(
                        tr('وەسف'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color:
                          isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                          isDark ? const Color(0xFF1A1A22) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tr(e.descriptionKu!),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        // ═══════════════════════════════════════
        // 🎯 دوگمەکانی خوارەوە
        // ═══════════════════════════════════════
        bottomNavigationBar: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              // ❤️ حەزکردن
              GestureDetector(
                onTap: _toggleInterest,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _isInterested
                        ? const Color(0xFFEF4444)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isInterested
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isInterested
                            ? Colors.white
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_interestedCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _isInterested
                              ? Colors.white
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 📞 پەیوەندی
              if (e.contactPhone != null && e.contactPhone!.isNotEmpty)
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final uri = Uri(scheme: 'tel', path: e.contactPhone);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('پەیوەندی'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Background
  // ═══════════════════════════════════════════════════════════
  Widget _buildGradientBg(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.event_rounded,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Info Row — Positional Parameters (چاککراو)
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoRow(
      IconData icon,
      String label,
      String value,
      Color color,
      bool isDark,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(label),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(value),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Category Label
  // ═══════════════════════════════════════════════════════════
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