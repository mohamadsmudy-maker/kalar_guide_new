import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import '../services/app_control.dart';
import '../services/auth_service.dart';

/// 🚧 دەرگای ئەپ: بەپێی کۆنترۆڵی ئەدمین، کاتێک «حالەتی چاککردن» چالاک بێت یان
/// وەشانی ئەپەکە لە کەمترین وەشان کەمتر بێت، شاشەیەکی بلۆککەر پیشان دەدات.
/// ئەدمین هەرگیز بلۆک ناکرێت (بۆ ئەوەی خۆی لە دەرەوە نەمێنێتەوە).
class AppGate extends StatelessWidget {
  final Widget child;
  final String? currentVersion;

  /// بۆ تێست
  final ValueListenable<AppControlState>? controlOverride;

  const AppGate({
    super.key,
    required this.child,
    this.currentVersion,
    this.controlOverride,
  });

  @override
  Widget build(BuildContext context) {
    final source = controlOverride ?? AppControl.state;
    return ValueListenableBuilder<AppControlState>(
      valueListenable: source,
      builder: (context, s, _) {
        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: AuthSessionManager.userNotifier,
          builder: (context, _, __) {
            final exempt = AuthSessionManager.isAdmin;
            final version = currentVersion ?? AppControl.currentVersion;
            final Widget? block = exempt
                ? null
                : s.maintenance
                    ? _Block(
                        icon: Icons.construction_rounded,
                        title: tr('ئەپەکە لە چاککردندایە'),
                        message: s.maintenanceMessage.isEmpty
                            ? tr('بەم زووانە دەگەڕێینەوە. ببورە بۆ ئەم کێشەیە.')
                            : s.maintenanceMessage,
                        buttonLabel: tr('دووبارە هەوڵبدەوە'),
                        onPressed: () => AppControl.instance.refresh(force: true),
                      )
                    : s.needsUpdate(version)
                        ? _Block(
                            icon: Icons.system_update_rounded,
                            title: tr('نوێکردنەوە پێویستە'),
                            message: s.updateMessage.isEmpty
                                ? tr('تکایە ئەپەکە بۆ دوایین وەشان نوێ بکەرەوە بۆ ئەوەی بەردەوام بیت.')
                                : s.updateMessage,
                            buttonLabel: s.updateUrl.isEmpty ? null : tr('نوێکردنەوە'),
                            onPressed: () async {
                              final uri = Uri.tryParse(s.updateUrl);
                              if (uri != null) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          )
                        : null;
            return Stack(
              fit: StackFit.expand,
              children: [child, if (block != null) block],
            );
          },
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback onPressed;

  const _Block({
    required this.icon,
    required this.title,
    required this.message,
    required this.onPressed,
    this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B1E45),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: const Color(0xFFFCD34D)),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.7),
                ),
                if (buttonLabel != null) ...[
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFCD34D),
                      foregroundColor: const Color(0xFF0B1E45),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(buttonLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
