// lib/widgets/live_users_badge.dart
import 'package:flutter/material.dart';
import '../services/presence_service.dart';
import '../screens/admin/admin_live_users.dart';

/// 🔴 Live Users Badge — لە AppBar
class LiveUsersBadge extends StatelessWidget {
  const LiveUsersBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: PresenceService.watchOnlineCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminLiveUsersScreen(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.people, color: Colors.white, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}