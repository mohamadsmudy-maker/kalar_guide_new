// lib/screens/admin/admin_live_users.dart
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../services/presence_service.dart';

/// 👥 شاشەی بەکارهێنەرانی چالاک — Live Ultra Pro
class AdminLiveUsersScreen extends StatefulWidget {
  const AdminLiveUsersScreen({super.key});

  @override
  State<AdminLiveUsersScreen> createState() => _AdminLiveUsersScreenState();
}

class _AdminLiveUsersScreenState extends State<AdminLiveUsersScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadStats();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _loadStats() async {
    final stats = await PresenceService.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.people_alt_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'بەکارهێنەرانی چالاک',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _loadStats();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLiveCard(),
            const SizedBox(height: 16),
            _buildStatsGrid(isDark),
            const SizedBox(height: 16),
            _buildUsersList(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCard() {
    return StreamBuilder<int>(
      stream: PresenceService.watchOnlineCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? (_stats['online_now'] ?? 0);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'ئێستا چالاک',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'بەکارهێنەر',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.wifi_tethering_rounded,
                color: Colors.white,
                size: 40,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final items = [
      _StatItem('٥ خولەکی ڕابردوو', _stats['last_5min'] ?? 0,
          Icons.timer_rounded, const Color(0xFF3B82F6)),
      _StatItem('٣٠ خولەکی ڕابردوو', _stats['last_30min'] ?? 0,
          Icons.hourglass_bottom_rounded, const Color(0xFF8B5CF6)),
      _StatItem('کاتژمێری ڕابردوو', _stats['last_1hour'] ?? 0,
          Icons.access_time_rounded, const Color(0xFFF59E0B)),
      _StatItem('ئەمڕۆ', _stats['today'] ?? 0, Icons.today_rounded,
          const Color(0xFFEF4444)),
      _StatItem('کۆی گشتی', _stats['total_users'] ?? 0,
          Icons.people_outline_rounded, const Color(0xFF06B6D4)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'ئاماری تەواو',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => _buildStatRow(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatRow(_StatItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${item.value}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: item.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: PresenceService.watchOnlineUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.list_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'لیستی بەکارهێنەران',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${users.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'هیچ بەکارهێنەرێکی چالاک نییە',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                ...users.take(20).map((user) => _buildUserTile(user, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isDark) {
    final name = user['user_name']?.toString() ?? 'میوان';
    final platform = user['platform']?.toString() ?? 'android';
    final language = user['language']?.toString() ?? 'ku';
    final lastSeen = DateTime.tryParse(user['last_seen'] ?? '');
    final timeAgo = _timeAgo(lastSeen);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(_platformIcon(platform),
                        style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      language.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: TextStyle(
              fontSize: 11,
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return '🤖';
      case 'ios':
        return '🍎';
      case 'web':
        return '🌐';
      default:
        return '📱';
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().toUtc().difference(date);
    if (diff.inSeconds < 30) return 'ئێستا';
    if (diff.inMinutes < 1) return '${diff.inSeconds} چرکە';
    if (diff.inMinutes < 60) return '${diff.inMinutes} خولەک';
    return '${diff.inHours} کاتژمێر';
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}