import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/translations.dart';
import '../../services/auth_service.dart';
import '../../utils/password_hasher.dart';

/// 🔐 شاشەی چوونەژوورەوە و دروستکردنی ئەکاونت
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _storeCodeCtrl = TextEditingController();

  String _selectedRole = 'customer';
  bool _isSignUp = false;
  bool _obscurePass = true;
  bool _loading = false;

  List<Map<String, dynamic>> _allStores = [];
  Map<String, dynamic>? _selectedStore;
  bool _loadingStores = false;
  bool _storeCodeVerified = false;

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _storeCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStores() async {
    setState(() => _loadingStores = true);
    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('id, name, phone, category')
          .order('name');

      if (mounted) {
        setState(() {
          _allStores = List<Map<String, dynamic>>.from(res);
          _loadingStores = false;
        });
      }
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی شوێنەکان: $e');
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  void _verifyStoreCode() {
    if (_selectedStore == null) {
      _showSnackBar('تکایە سەرەتا شوێنێک هەڵبژێرە', Colors.orange);
      return;
    }

    final enteredCode = _storeCodeCtrl.text.trim();
    final realCode = _selectedStore!['phone']?.toString().trim() ?? '';

    if (enteredCode.isEmpty) {
      _showSnackBar('تکایە کۆدەکە بنووسە', Colors.orange);
      return;
    }

    if (enteredCode == realCode) {
      setState(() => _storeCodeVerified = true);
      _showSnackBar('کۆد ڕاستە ✅', Colors.green);
    } else {
      setState(() => _storeCodeVerified = false);
      _showSnackBar('کۆد هەڵەیە ❌', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 ناردنی فۆرم
  // ═══════════════════════════════════════════════════════════
  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    // ✅ پشکنینەکان
    if (phone.isEmpty || pass.isEmpty) {
      _showSnackBar('مۆبایل و پاسۆرد پێویستە ⚠', Colors.orange);
      return;
    }
    if (pass.length < 6) {
      _showSnackBar('پاسۆرد دەبێت لانیکەم ٦ پیت بێت ⚠', Colors.orange);
      return;
    }
    if (phone.length < 10) {
      _showSnackBar('ژمارەی مۆبایل دروست نییە ⚠', Colors.orange);
      return;
    }

    if (_isSignUp) {
      if (_selectedRole == 'vendor' || _selectedRole == 'department') {
        if (_selectedStore == null) {
          _showSnackBar('تکایە شوێنەکەت هەڵبژێرە 🏪', Colors.orange);
          return;
        }
        if (!_storeCodeVerified) {
          _showSnackBar('تکایە کۆدی شوێن پشتڕاست بکەرەوە 🔑', Colors.orange);
          return;
        }
      } else {
        if (name.isEmpty) {
          _showSnackBar('ناوی تەواو پێویستە', Colors.orange);
          return;
        }
      }
    }

    setState(() => _loading = true);

    final hashedPass = PasswordHasher.hash(pass);

    try {
      if (_isSignUp) {
        await _handleSignUp(phone, pass, name, hashedPass);
      } else {
        await _handleLogin(phone, pass);
      }
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) _showSnackBar('هەڵە: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✍️ دروستکردنی ئەکاونت
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleSignUp(
      String phone,
      String pass,
      String name,
      String hashedPass,
      ) async {
    // پشکنینی مۆبایل
    final dukanExists = await Supabase.instance.client
        .from('dukan')
        .select('id')
        .eq('user_phone', phone)
        .maybeSingle();

    final userExists = await Supabase.instance.client
        .from('app_users')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();

    if (dukanExists != null || userExists != null) {
      _showSnackBar('ئەم ژمارەیە پێشتر تۆمار کراوە ⚠', Colors.orange);
      return;
    }

    if (_selectedRole == 'vendor' || _selectedRole == 'department') {
      // ڤێندەر / فەرمانگە — لە `dukan` نوێکردنەوە
      await Supabase.instance.client.from('dukan').update({
        'user_phone': phone,
        'password': hashedPass,
        'is_approved': false,
        'vendor_role': _selectedRole,
      }).eq('id', _selectedStore!['id']);

      _showSnackBar(
        'داواکاریت بۆ ${_selectedStore!['name']} نێردرا ⏳\nچاوەڕێی پەسەندی ئەدمین بە',
        Colors.green,
      );

      setState(() {
        _isSignUp = false;
        _storeCodeVerified = false;
        _selectedStore = null;
        _storeCodeCtrl.clear();
        _phoneCtrl.clear();
        _passCtrl.clear();
      });
      return;
    }

    // کڕیار — لە `app_users` تۆمار
    await Supabase.instance.client.from('app_users').insert({
      'name': name,
      'phone': phone,
      'password': hashedPass,
      'role': 'customer',
      'is_approved': true,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_phone', phone);
    await AuthSessionManager.fetchUserProfile();

    if (mounted) Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 چوونەژوورەوە — بە پشتگیری هەموو جۆرەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleLogin(String phone, String pass) async {
    final result = await AuthSessionManager.login(
      phone: phone,
      password: pass,
    );

    if (result == null) {
      _showSnackBar('مۆبایل یان پاسۆرد هەڵەیە ❌', Colors.red);
      return;
    }

    // ⚠️ چاوەڕوانی پەسەندکردن
    if (result['__pending_approval__'] == true) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('چاوەڕوان بە ⏳'),
                ],
              ),
              content: const Text(
                'هێشتا داواکاریت لەلایەن ئەدمینەوە پەسەند نەکراوە.\n\n'
                    'تکایە چاوەڕوان بە تا پەسەند دەکرێیت.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('باشە'),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    // ✅ سەرکەوتوو
    if (mounted) Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF5F7),
        appBar: AppBar(
          title: Text(_isSignUp ? 'دروستکردنی ئەکاونت' : 'چوونەژوورەوە'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  // لۆگۆ
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(15),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/kalar.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.explore_rounded,
                            size: 50,
                            color: AppColors.primary,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isSignUp) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'جۆری ئەکاونت',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(
                          Icons.person_pin_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('👤 بەکارهێنەر'),
                        ),
                        DropdownMenuItem(
                          value: 'vendor',
                          child: Text('🏪 فرۆشیار / شوێن'),
                        ),
                        DropdownMenuItem(
                          value: 'department',
                          child: Text('🏛️ فەرمانگە'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedRole = v!;
                        _storeCodeVerified = false;
                        _selectedStore = null;
                      }),
                    ),
                    const SizedBox(height: 14),

                    if (_selectedRole == 'vendor' ||
                        _selectedRole == 'department') ...[
                      _loadingStores
                          ? const CircularProgressIndicator(
                        color: AppColors.primary,
                      )
                          : DropdownButtonFormField<Map<String, dynamic>>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _selectedRole == 'department'
                              ? 'فەرمانگەکەت هەڵبژێرە *'
                              : 'شوێنەکەت هەڵبژێرە *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(
                            _selectedRole == 'department'
                                ? Icons.business_rounded
                                : Icons.storefront_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        initialValue: _selectedStore,
                        items: _allStores.map((store) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: store,
                            child: Text(
                              '${store['name']} (${store['category'] ?? ''})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() {
                          _selectedStore = val;
                          _storeCodeVerified = false;
                          _storeCodeCtrl.clear();
                        }),
                      ),
                      const SizedBox(height: 14),

                      if (_selectedStore != null) ...[
                        TextField(
                          controller: _storeCodeCtrl,
                          onChanged: (_) =>
                              setState(() => _storeCodeVerified = false),
                          decoration: InputDecoration(
                            labelText: 'کۆدی نهێنی شوێن *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.orange.shade50,
                            prefixIcon: const Icon(
                              Icons.vpn_key_rounded,
                              color: AppColors.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _storeCodeVerified
                                    ? Icons.check_circle
                                    : Icons.verified_outlined,
                                color: _storeCodeVerified
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                              onPressed: _verifyStoreCode,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _verifyStoreCode,
                            child: Text(
                              _storeCodeVerified
                                  ? 'کۆد ڕاستە ✅'
                                  : 'پشتڕاستکردنەوەی کۆد',
                              style: TextStyle(
                                color: _storeCodeVerified
                                    ? Colors.green
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'ناوی تەواو',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],

                  // مۆبایل
                  TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      labelText: _selectedRole == 'vendor' && _isSignUp
                          ? 'ژمارەی مۆبایلی خۆت * (بۆ لۆگین)'
                          : 'ژمارەی مۆبایل *',
                      hintText: '0770xxxxxxx',
                      prefixIcon: const Icon(
                        Icons.phone_iphone_rounded,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  // پاسۆرد
                  TextField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'پاسۆرد * (لانیکەم ٦ پیت)',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: _obscurePass,
                  ),
                  const SizedBox(height: 28),

                  // دوگمەی ناردن
                  _loading
                      ? const CircularProgressIndicator(
                    color: AppColors.primary,
                  )
                      : SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _submit,
                      child: Text(
                        _isSignUp
                            ? 'دروستکردنی ئەکاونت'
                            : 'چوونەژوورەوە',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // گۆڕین
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'ئەکاونتت هەیە؟ بچۆ ژوورەوە'
                          : 'ئەکاونتت نییە؟ دروستبکە',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}