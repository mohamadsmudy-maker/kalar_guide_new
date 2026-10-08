import 'package:flutter/material.dart';
import 'admin_currency_stations.dart';

/// 💱 شاشەی بەڕێوەبردنی دراو (Wrapper)
class AdminCurrencyScreen extends StatelessWidget {
  const AdminCurrencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminCurrencyStationsScreen();  // ✅ چاککراو
  }
}