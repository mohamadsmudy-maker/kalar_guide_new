import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 💵 شاشەی بەڕێوەبردنی نرخی دراوەکان
class AdminCurrencyScreen extends StatefulWidget {
  const AdminCurrencyScreen({super.key});

  @override
  State<AdminCurrencyScreen> createState() => _AdminCurrencyScreenState();
}

class _AdminCurrencyScreenState extends State<AdminCurrencyScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rates = [];

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('currency_rates')
          .select()
          .order('id', ascending: true);
      if (mounted) {
        setState(() {
          _rates = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditor({Map<String, dynamic>? rate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CurrencyEditor(rate: rate),
    ).then((_) => _fetchRates());
  }

  Future<void> _deleteRate(dynamic id) async {
    try {
      await Supabase.instance.client
          .from('currency_rates')
          .delete()
          .eq('id', id);
      _fetchRates();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: const Text(
            "نرخی دراوەکان 💵",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _rates.isEmpty
            ? const Center(
          child: Text(
            "هیچ دراوێک تۆمار نەکراوە 📭",
            style: TextStyle(color: Colors.grey),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _rates.length,
          itemBuilder: (context, index) {
            var rate = _rates[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    rate['flag_emoji'] ?? '💵',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                title: Text(
                  rate['currency_name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "کڕین: ${rate['buy_price']} | فرۆشتن: ${rate['sell_price']}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () => _openEditor(rate: rate),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _deleteRate(rate['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _CurrencyEditor extends StatefulWidget {
  final Map<String, dynamic>? rate;
  const _CurrencyEditor({this.rate});

  @override
  State<_CurrencyEditor> createState() => _CurrencyEditorState();
}

class _CurrencyEditorState extends State<_CurrencyEditor> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _flagCtrl = TextEditingController();
  final _buyCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.rate != null) {
      _codeCtrl.text = widget.rate!['currency_code'] ?? '';
      _nameCtrl.text = widget.rate!['currency_name'] ?? '';
      _flagCtrl.text = widget.rate!['flag_emoji'] ?? '';
      _buyCtrl.text = widget.rate!['buy_price']?.toString() ?? '';
      _sellCtrl.text = widget.rate!['sell_price']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _flagCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      final data = {
        'currency_code': _codeCtrl.text.trim().toUpperCase(),
        'currency_name': _nameCtrl.text.trim(),
        'flag_emoji': _flagCtrl.text.trim().isEmpty
            ? '💵'
            : _flagCtrl.text.trim(),
        'buy_price': num.tryParse(_buyCtrl.text.trim()) ?? 0,
        'sell_price': num.tryParse(_sellCtrl.text.trim()) ?? 0,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.rate == null) {
        await Supabase.instance.client.from('currency_rates').insert(data);
      } else {
        await Supabase.instance.client
            .from('currency_rates')
            .update(data)
            .eq('id', widget.rate!['id']);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "دەستکاریکردنی دراو",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(),
              TextField(
                controller: _codeCtrl,
                decoration: InputDecoration(
                  labelText: 'کۆد (USD، EUR...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'ناو',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _flagCtrl,
                decoration: InputDecoration(
                  labelText: 'ئیمۆجی (🇺🇸، 🇪🇺...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _buyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'نرخی کڕین',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sellCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'نرخی فرۆشتن',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _save,
                  child: const Text(
                    'پاشەکەوتکردن',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}