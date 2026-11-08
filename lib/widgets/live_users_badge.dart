// lib/widgets/live_users_badge.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../screens/admin/admin_live_users.dart';
import '../l10n/tr.dart';

/// 🔴 Live Users Badge — لە AppBar — ULTRA PRO MAX V2
class LiveUsersBadge extends StatefulWidget {
  /// Show the badge even when nobody is online (shows ٠)
  final bool showWhenZero;

  /// Override what a tap does. Default: open the live-users admin screen
  /// (only for admins).
  final VoidCallback? onTap;

  const LiveUsersBadge({
    super.key,
    this.showWhenZero = false,
    this.onTap,
  });

  @override
  State<LiveUsersBadge> createState() => _LiveUsersBadgeState();
}

class _LiveUsersBadgeState extends State<LiveUsersBadge>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF0F9D7A);

  StreamSubscription<int>? _sub;
  late final AnimationController _pulse;

  /// Last known value — kept in State so a rebuild of the parent never
  /// re-creates the stream or makes the badge flash empty.
  int _count = 0;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    try {
      _sub = PresenceService.watchOnlineCount().listen(
            (c) {
          if (mounted) {
            setState(() {
              _count = c;
              _hasData = true;
            });
          }
        },
        onError: (e) => debugPrint('⚠️ LiveUsersBadge stream error: $e'),
      );
    } catch (e) {
      debugPrint('⚠️ LiveUsersBadge setup error: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ♿ no endless pulsing when the user asked for reduced motion
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _ku(Object n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  /// 1234 → ١٫٢k
  String _compact(int n) {
    if (n < 1000) return _ku(n);
    final k = (n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1);
    return '${_ku(k.replaceAll('.', '٫'))}k';
  }

  bool get _canOpen => widget.onTap != null || AuthSessionManager.isAdmin;

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminLiveUsersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _hasData && (_count > 0 || widget.showWhenZero);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: visible
          ? _buildBadge(context)
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final canOpen = _canOpen;

    final badge = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_green, Color(0xFF0F9D7A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // pulsing "live" dot
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.7 * _pulse.value),
                    blurRadius: 6,
                    spreadRadius: 2 * _pulse.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // the number slides / fades when it changes
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              tr(_compact(_count)),
              key: ValueKey(_count),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.people, color: Colors.white, size: 14),
        ],
      ),
    );

    return Semantics(
      key: const ValueKey('badge'),
      button: canOpen,
      label: trf('{0} بەکارهێنەر ئێستا لە خەتە', [_ku(_count)]),
      child: ExcludeSemantics(
        child: canOpen
        // 44px-tall tap area (the badge itself is only ~28px)
            ? GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: SizedBox(height: 44, child: Center(child: badge)),
        )
        // regular users just see the number — it must not open an admin screen
            : badge,
      ),
    );
  }
}