import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 🔔 شاشەی ناردنی ئاگاداری — بە Supabase Edge Function
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isLoading = false;
  String _target = 'all';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە ناونیشان و دەق پڕبکەرەوە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // ✅ بانگکردنی Edge Function بۆ ناردنی FCM
      final response = await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'target': _target,
        },
      );

      debugPrint('📤 Function response: ${response.status} - ${response.data}');

      // ✅ تۆمارکردن لە داتابەیس بۆ مێژوو
      await Supabase.instance.client.from('notifications').insert({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'target': _target,
        'sent_count': response.data?['sent'] ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        final sentCount = response.data?['sent'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ ئاگاداری نێردرا بۆ $sentCount بەکارهێنەر",
            ),
            backgroundColor: Colors.green,
          ),
        );
        _titleCtrl.clear();
        _bodyCtrl.clear();
      }
    } catch (e) {
      debugPrint('❌ Notification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("هەڵە: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: const Text(
            "ناردنی ئاگاداری 🔔",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "ناونیشان *",
                    prefixIcon: const Icon(
                      Icons.title_rounded,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor:
                    isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "دەق *",
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(
                      Icons.description_rounded,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor:
                    isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // 🎯 هەڵبژاردنی ئامانج
                Text(
                  "ئامانج",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTargetChip('all', 'هەمووان', Icons.people_rounded),
                    _buildTargetChip(
                      'customers',
                      'کڕیارەکان',
                      Icons.person_rounded,
                    ),
                    _buildTargetChip(
                      'vendors',
                      'فرۆشیارەکان',
                      Icons.storefront_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                      : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _sendNotification,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      "ناردن ✅",
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildTargetChip(String value, String label, IconData icon) {
    final isSelected = _target == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _target = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF0F0F14) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}