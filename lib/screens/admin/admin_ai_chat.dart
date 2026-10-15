import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ai_service.dart';

// (CountOption لە Supabase Flutter هەیە)
/// 🤖 شاشەی ڕاپۆرتی زیرەک بە چات
class AdminAiChatScreen extends StatefulWidget {
  const AdminAiChatScreen({super.key});

  @override
  State<AdminAiChatScreen> createState() => _AdminAiChatScreenState();
}

class _AdminAiChatScreenState extends State<AdminAiChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
      'سڵاو بەڕێوەبەر! من یاریدەدەری زیرەکی تۆم. دەتوانیت هەر پرسیارێکت هەبێت دەربارەی ڕاپۆرتی فرۆش، داهات، یان ئۆردەرەکان لێرە بپرسیت 📊',
    },
  ];
  bool _loading = false;

  Future<void> _handleUserQuery(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _loading = true;
    });
    _msgCtrl.clear();

    try {
      final supa = Supabase.instance.client;

      // ⭐ ١. کۆی ئۆردەرەکان (تەنها Count، بێ داتا)
      final countRes = await supa
          .from('orders')
          .select('id')
          .count(CountOption.exact);
      final totalOrders = countRes.count ?? 0;

      // ⭐ ٢. کۆی داهات (تەنها ١٠٠ دوایین)
      final recentRes = await supa
          .from('orders')
          .select('total_price, store_name, status, created_at')
          .order('created_at', ascending: false)
          .limit(100);

      final recentOrders = List<Map<String, dynamic>>.from(recentRes);

      // ⭐ ٣. حسابی داهاتی گشتی لە Supabase
      // (بەکارهێنانی RPC یان Views دەتوانێت خێراتر بێت)
      double recentRevenue = 0;
      for (var o in recentOrders) {
        recentRevenue +=
            double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
      }

      // ⭐ ٤. ئامادەکردنی کورتە (بە کوردی)
      final dataSummary = '''
📊 ئاماری گشتی:
- کۆی داواکارییەکان: $totalOrders
- کۆی داهات (دوایین ١٠٠): ${recentRevenue.toStringAsFixed(0)} د.ع
- تێکڕای داهات: ${(recentOrders.isNotEmpty ? recentRevenue / recentOrders.length : 0).toStringAsFixed(0)} د.ع

📋 دوایین ١٠ داواکاری:
${recentOrders.take(10).map((o) => "- ${o['store_name']}: ${o['total_price']} د.ع (${o['status']})").join('\n')}
''';

      // ⭐ ٥. پرسیار لە AI
      final aiResponse = await AiService.askAdminAI(query, dataSummary);

      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': aiResponse});
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': 'هەڵەیەک ڕووی دا: $e',
          });
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F5FA),
        appBar: AppBar(
          title: const Text(
            "ڕاپۆرتی زیرەک بە چات (AI Chat) 🤖",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor: const Color(0xFF1E1B2E),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  bool isAi = msg['role'] == 'ai';
                  return Align(
                    alignment:
                    isAi ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color:
                        isAi ? Colors.white : const Color(0xFFE91E63),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isAi ? Colors.black87 : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(color: Color(0xFFE91E63)),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        decoration: InputDecoration(
                          hintText: "پرسیارت بنووسە (بۆ نموونە: داهاتی گشتی چەندە؟)...",
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F3),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _handleUserQuery,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE91E63),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => _handleUserQuery(_msgCtrl.text),
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
}