import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 🌤️ شاشەی بەڕێوەبردنی کەشوهەوا
class AdminWeatherScreen extends StatefulWidget {
  const AdminWeatherScreen({super.key});

  @override
  State<AdminWeatherScreen> createState() => _AdminWeatherScreenState();
}

class _AdminWeatherScreenState extends State<AdminWeatherScreen> {
  final _tempCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _humidityCtrl = TextEditingController();
  final _windCtrl = TextEditingController();
  bool _loading = false;
  bool _fetching = true;
  dynamic _recordId;

  @override
  void initState() {
    super.initState();
    _fetchCurrent();
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _conditionCtrl.dispose();
    _humidityCtrl.dispose();
    _windCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrent() async {
    try {
      final res = await Supabase.instance.client
          .from('weather')
          .select()
          .order('id', ascending: false)
          .maybeSingle();

      if (res != null) {
        _recordId = res['id'];
        _tempCtrl.text = res['temperature']?.toString() ?? '';
        _conditionCtrl.text = res['condition_text'] ?? '';
        _humidityCtrl.text = res['humidity']?.toString() ?? '';
        _windCtrl.text = res['wind_speed']?.toString() ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _fetching = false);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final data = {
        'city': 'کەلار',
        'temperature': int.tryParse(_tempCtrl.text.trim()) ?? 25,
        'condition_text': _conditionCtrl.text.trim().isEmpty
            ? 'ساماڵ'
            : _conditionCtrl.text.trim(),
        'humidity': int.tryParse(_humidityCtrl.text.trim()) ?? 30,
        'wind_speed': int.tryParse(_windCtrl.text.trim()) ?? 10,
        'icon_emoji': '🌤️',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_recordId == null) {
        await Supabase.instance.client.from('weather').insert(data);
      } else {
        await Supabase.instance.client
            .from('weather')
            .update(data)
            .eq('id', _recordId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("کەشوهەوا نوێکرایەوە ✅"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
            "بەڕێوەبردنی کەشوهەوا 🌤️",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _fetching
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tempCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "پلەی گەرما (°C)",
                    prefixIcon: const Icon(
                      Icons.thermostat,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _conditionCtrl,
                  decoration: InputDecoration(
                    labelText: "دۆخ (ساماڵ، هەور...)",
                    prefixIcon: const Icon(
                      Icons.cloud,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _humidityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "شێدارى (%)",
                    prefixIcon: const Icon(
                      Icons.water_drop,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _windCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "خێرایی با (کم/س)",
                    prefixIcon: const Icon(
                      Icons.air,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _loading
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _save,
                    child: const Text(
                      "پاشەکەوتکردن ✅",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
}