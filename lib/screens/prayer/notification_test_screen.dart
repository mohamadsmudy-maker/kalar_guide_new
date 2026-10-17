import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/prayer_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
/// 🧪 شاشەی تاقیکردنەوەی Notifications
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() =>
      _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _permissionsGranted = false;
  bool _loading = true;
  bool _busy = false;
  List<PendingNotificationRequest> _pending = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _checkPermissions();
    await _loadPending();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = await PrayerNotificationService.requestPermissions();
      if (mounted) setState(() => _permissionsGranted = granted);
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      if (mounted) setState(() => _permissionsGranted = false);
    }
  }

  Future<void> _loadPending() async {
    try {
      final pending =
      await PrayerNotificationService.getPendingNotifications();
      if (mounted) setState(() => _pending = pending);
    } catch (e) {
      debugPrint('❌ Pending error: $e');
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('❌ Action error: $e');
      if (!mounted) return;
      _showSnack('⚠️ هەڵە: $e', const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: const Text(
            '🧪 تاقیکردنەوەی Notifications',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'نوێکردنەوەی لیست',
              onPressed: _busy ? null : _loadPending,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),

            // ⭐ Notification ی ئێستا
            _buildTestButton(
              icon: Icons.notifications_active_rounded,
              title: 'Notification ی ئێستا',
              subtitle: '٢ چرکە دواتر دەردەکەوێت',
              color: const Color(0xFF3B82F6),
              onTap: () => _runBusy(() async {
                await PrayerNotificationService
                    .scheduleTestNotification(
                  delay: const Duration(seconds: 2),
                );
                HapticFeedback.mediumImpact();
                if (!mounted) return;
                _showSnack(
                  '⏱️ چاوەڕوان بە ٢ چرکە...',
                  const Color(0xFF3B82F6),
                );
                await _loadPending();
              }),
            ),

            const SizedBox(height: 12),

            // ⭐ Notification ی داهاتوو
            _buildTestButton(
              icon: Icons.schedule_rounded,
              title: 'Notification ی داهاتوو',
              subtitle: '١٥ چرکە دواتر دەردەکەوێت',
              color: const Color(0xFFFFD700),
              onTap: () => _runBusy(() async {
                await PrayerNotificationService
                    .scheduleTestNotification(
                  delay: const Duration(seconds: 15),
                );
                HapticFeedback.mediumImpact();
                if (!mounted) return;
                _showSnack(
                  '⏱️ چاوەڕوان بە ١٥ چرکە...',
                  const Color(0xFFFFD700),
                );
                await _loadPending();
              }),
            ),

            const SizedBox(height: 12),

            // ⭐ Schedule ی ٥ نوێژ
            _buildTestButton(
              icon: Icons.schedule_send_rounded,
              title: 'Schedule ی ٥ نوێژ',
              subtitle: 'بۆ تاقیکردنەوە — هەر ٣٠ چرکە',
              color: const Color(0xFF10B981),
              onTap: () => _runBusy(() async {
                final now = DateTime.now();
                final testTimes = <String, String>{};
                const names = [
                  'بەیانی',
                  'نیوەڕۆ',
                  'عەسر',
                  'مەغریب',
                  'عیشا',
                ];
                for (int i = 0; i < 5; i++) {
                  final time =
                  now.add(Duration(seconds: 10 + (i * 30)));
                  final hour =
                  time.hour.toString().padLeft(2, '0');
                  final minute =
                  time.minute.toString().padLeft(2, '0');
                  testTimes[names[i]] = '$hour:$minute';
                }

                await PrayerNotificationService.scheduleAllPrayers(
                  prayerTimes: testTimes,
                  is24Hour: true,
                );

                if (!mounted) return;
                _showSnack(
                  '✅ ٥ Notification scheduled',
                  const Color(0xFF10B981),
                );
                await _loadPending();
              }),
            ),

            const SizedBox(height: 20),

            // ⭐ پاککردنەوە
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runBusy(() async {
                  await PrayerNotificationService
                      .cancelAll();
                  await _loadPending();
                  if (!mounted) return;
                  _showSnack(
                    '🗑️ هەموو Notifications سڕایەوە',
                    const Color(0xFFEF4444),
                  );
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text(
                  'سڕینەوەی هەموو Notifications',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_pending.isNotEmpty) ...[
              Text(
                '📋 Notifications ی چاوەڕوان (${_pending.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ..._pending.map(_buildPendingItem),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'هیچ Notification ی چاوەڕوان نییە',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _permissionsGranted
              ? [
            const Color(0xFF10B981).withValues(alpha: 0.2),
            const Color(0xFF10B981).withValues(alpha: 0.05),
          ]
              : [
            const Color(0xFFEF4444).withValues(alpha: 0.2),
            const Color(0xFFEF4444).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _permissionsGranted
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _permissionsGranted
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : const Color(0xFFEF4444).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _permissionsGranted
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: _permissionsGranted
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _permissionsGranted
                      ? '✅ مۆڵەت دراوە'
                      : '❌ مۆڵەت نەدراوە',
                  style: TextStyle(
                    color: _permissionsGranted
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _permissionsGranted
                      ? 'Notifications کار دەکەن'
                      : 'تکایە مۆڵەت بدە',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!_permissionsGranted)
            IconButton(
              icon: const Icon(
                Icons.settings_rounded,
                color: Color(0xFFEF4444),
              ),
              onPressed: _checkPermissions,
            ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: _busy ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2030),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingItem(PendingNotificationRequest p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFFFD700),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title ?? 'بێ ناونیشان',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.body ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '#${p.id}',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}