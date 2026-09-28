import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 📈 ڕاپۆرتی پرۆ
class SuperAdminReportScreen extends StatefulWidget {
  const SuperAdminReportScreen({super.key});

  @override
  State<SuperAdminReportScreen> createState() =>
      _SuperAdminReportScreenState();
}

class _SuperAdminReportScreenState extends State<SuperAdminReportScreen> {
  bool _isLoading = true;
  int _totalOrders = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('orders')
          .select('id, total_price');

      final list = List<Map<String, dynamic>>.from(res);
      double revenue = 0;
      for (var o in list) {
        revenue +=
            double.tryParse(o['total_price']?.toString() ?? '0') ?? 0;
      }

      if (mounted) {
        setState(() {
          _totalOrders = list.length;
          _totalRevenue = revenue;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: const Text(
            "ڕاپۆرتی پرۆ 📈",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "کۆی داهات",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${_totalRevenue.toStringAsFixed(0)} د.ع",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Text(
                      "کۆی ئۆردەرەکان: $_totalOrders",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}