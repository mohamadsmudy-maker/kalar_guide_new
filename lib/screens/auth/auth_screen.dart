// lib/screens/auth/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';

/// 🔐 شاشەی چوونەژوورەوە / تۆمارکردن — ULTRA PRO MAX V2
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
  bool _verifyingCode = false;

  static const int _minPasswordLength = 8;

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

  // ═══════════════════════════════════════════════════════════
  // 📥 هێنانی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchStores() async {
    if (mounted) setState(() => _loadingStores = true);

    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('id, name, phone, category') // 🔐 vendor_code نانێردرێت بۆ مۆبایل
          .order('name');

      if (!mounted) return;
      setState(() {
        _allStores = List<Map<String, dynamic>>.from(res as List);
        _loadingStores = false;
      });
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی شوێنەکان: $e');
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 پشکنینی کۆدی شوێن
  // ═══════════════════════════════════════════════════════════
  /// 🔐 کۆدەکە لەسەر سێرڤەر پشکنین دەکرێت (RPC: verify_vendor_code)
  /// — کۆدی ڕاستەقینە هەرگیز ناگاتە مۆبایل.
  Future<void> _verifyStoreCode() async {
    if (_selectedStore == null) {
      _showSnackBar('تکایە سەرەتا شوێنێک هەڵبژێرە', AppColors.orange);
      return;
    }

    final enteredCode = _storeCodeCtrl.text.trim();
    if (enteredCode.isEmpty) {
      _showSnackBar('تکایە کۆدەکە بنووسە', AppColors.orange);
      return;
    }
    if (_verifyingCode) return;

    setState(() => _verifyingCode = true);
    try {
      final ok = await Supabase.instance.client.rpc(
        'verify_vendor_code',
        params: {
          'p_store_id': _selectedStore!['id'].toString(),
          'p_code': enteredCode,
        },
      );
      if (!mounted) return;
      final isValid = ok == true;
      setState(() => _storeCodeVerified = isValid);
      _showSnackBar(
        isValid ? 'کۆد ڕاستە ✅' : 'کۆد هەڵەیە ❌',
        isValid ? AppColors.green : AppColors.red,
      );
    } catch (e) {
      debugPrint('❌ verify_vendor_code: $e');
      if (mounted) {
        setState(() => _storeCodeVerified = false);
        _showSnackBar('پشکنینی کۆد سەرنەکەوت، دووبارە هەوڵ بدەرەوە', AppColors.red);
      }
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💬 Snackbar
  // ═══════════════════════════════════════════════════════════
  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 ناردنی فۆرم
  // ═══════════════════════════════════════════════════════════
  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    // ✅ Pshknin
    if (phone.isEmpty || pass.isEmpty) {
      _showSnackBar('مۆبایل و پاسۆرد پێویستە ⚠', AppColors.orange);
      return;
    }
    // تەنها لە تۆمارکردندا درێژی پشکنین دەکرێت، بۆ ئەوەی بەکارهێنەرە کۆنەکان
    // (کە پاسۆردی ٦-٧ پیتییان هەیە) هێشتا بتوانن بچنە ژوورەوە.
    if (_isSignUp && pass.length < _minPasswordLength) {
      _showSnackBar(
        'پاسۆرد دەبێت لانیکەم $_minPasswordLength پیت بێت ⚠',
        AppColors.orange,
      );
      return;
    }
    if (phone.length < 10) {
      _showSnackBar('ژمارەی مۆبایل دروست نییە ⚠', AppColors.orange);
      return;
    }

    if (_isSignUp) {
      if (_selectedRole == 'admin') {
        if (_selectedStore == null) {
          _showSnackBar('تکایە شوێنەکەت هەڵبژێرە 🏪', AppColors.orange);
          return;
        }
        if (!_storeCodeVerified) {
          _showSnackBar('تکایە کۆدی شوێن پشتڕاست بکەرەوە 🔑', AppColors.orange);
          return;
        }
      } else {
        if (name.isEmpty) {
          _showSnackBar('ناوی تەواو پێویستە', AppColors.orange);
          return;
        }
      }
    }

    setState(() => _loading = true);

    try {
      if (_isSignUp) {
        await _handleSignUp(phone: phone, pass: pass, name: name);
      } else {
        await _handleSignIn(phone: phone, pass: pass);
      }
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      // هەڵەی ناوخۆیی (ناوی خشتە، SQL…) نیشانی بەکارهێنەر نادرێت
      if (mounted) {
        _showSnackBar('هەڵەیەک ڕوویدا، تکایە دووبارە هەوڵ بدەرەوە', AppColors.red);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 تۆمارکردن
  // ═══════════════════════════════════════════════════════════
  /// 🔐 پاسۆرد لەسەر سێرڤەر هاش دەکرێت (RPC: app_register_customer / app_request_vendor)
  Future<void> _handleSignUp({
    required String phone,
    required String pass,
    required String name,
  }) async {
    final client = Supabase.instance.client;

    if (_selectedRole == 'admin') {
      // ✅ داواکاری ڤێندەر — کۆدی شوێن دووبارە لەسەر سێرڤەر پشکنین دەکرێتەوە
      final res = await client.rpc('app_request_vendor', params: {
        'p_phone': phone,
        'p_password': pass,
        'p_store_id': _selectedStore!['id'].toString(),
        'p_vendor_code': _storeCodeCtrl.text.trim(),
      });
      if (!mounted) return;

      if (res == 'phone_exists') {
        _showSnackBar('ئەم ژمارەیە پێشتر تۆمار کراوە ⚠', AppColors.orange);
        return;
      }
      if (res != 'ok') {
        setState(() => _storeCodeVerified = false);
        _showSnackBar('کۆدی شوێن هەڵەیە ❌', AppColors.red);
        return;
      }

      _showSnackBar(
        'داواکاریت بۆ ${_selectedStore!['name']} نێردرا ⏳\nچاوەڕێی پەسەندی ئەدمین بە',
        AppColors.green,
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

    // ⭐ هاوڵاتی
    final res = await client.rpc('app_register_customer', params: {
      'p_name': name,
      'p_phone': phone,
      'p_password': pass,
    });
    if (!mounted) return;

    if (res == 'phone_exists') {
      _showSnackBar('ئەم ژمارەیە پێشتر تۆمار کراوە ⚠', AppColors.orange);
      return;
    }
    if (res != 'ok') {
      _showSnackBar('تۆمارکردن سەرنەکەوت', AppColors.red);
      return;
    }

    // چوونەژوورەوەی ڕاستەوخۆ دوای تۆمارکردن
    await _handleSignIn(phone: phone, pass: pass);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔓 چوونەژوورەوە
  // ═══════════════════════════════════════════════════════════
  /// 🔐 پاسۆرد لەسەر سێرڤەر پشکنین دەکرێت (RPC: app_login).
  /// هاشی پاسۆرد هەرگیز ناگاتە مۆبایل.
  Future<void> _handleSignIn({
    required String phone,
    required String pass,
  }) async {
    // 🔐 app_login ئەم session ـە بە بەکارهێنەرەکەوە دەبەستێتەوە لەسەر سێرڤەر
    if (Supabase.instance.client.auth.currentSession == null) {
      await Supabase.instance.client.auth.signInAnonymously();
    }
    final res = await Supabase.instance.client.rpc('app_login', params: {
      'p_phone': phone,
      'p_password': pass,
    });
    if (!mounted) return;

    final rows = res is List ? res : const [];
    if (rows.isEmpty) {
      _showSnackBar('مۆبایل یان پاسۆرد هەڵەیە ❌', AppColors.red);
      return;
    }
    final userRes = Map<String, dynamic>.from(rows.first as Map);

    // ⭐ پشکنینی پەسەندکردنی ڤێندەر
    final role = userRes['role']?.toString();
    final isApproved = userRes['is_approved'] == true;
    if (role == 'vendor_pending' || (role == 'vendor' && !isApproved)) {
      await _showPendingDialog();
      return;
    }

    await AuthSessionManager.saveSession(
      phone: phone,
      name: userRes['name']?.toString(),
      id: userRes['id'],
      role: role ?? 'customer',
      storeId: userRes['store_id'],
    );

    if (mounted) Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Dialog بۆ ڤێندەری چاوەڕوان
  // ═══════════════════════════════════════════════════════════
  Future<void> _showPendingDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: AppColors.orange),
              SizedBox(width: 8),
              Text(
                'چاوەڕوان بە ⏳',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: const Text(
            'هێشتا داواکاریت لەلایەن ئەدمینەوە پەسەند نەکراوە.\n\nتکایە چاوەڕوان بە تا پەسەند دەکرێیت.',
            style: TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'باشە',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            _isSignUp ? 'دروستکردنی ئەکاونت' : 'چوونەژوورەوە',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Column(
                children: [
                  _buildLogo(),
                  const SizedBox(height: 30),

                  // 🎭 Role selector
                  if (_isSignUp) ...[
                    _buildRoleDropdown(isDark),
                    const SizedBox(height: 14),
                  ],

                  // 📱 Phone
                  _buildTextField(
                    controller: _phoneCtrl,
                    label: 'ژمارەی مۆبایل *',
                    hint: '0770xxxxxxx',
                    icon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // 🏪 Admin-only fields
                  if (_isSignUp && _selectedRole == 'admin') ...[
                    _buildStoreSelector(isDark),
                    const SizedBox(height: 14),
                    if (_selectedStore != null) ...[
                      _buildStoreCodeField(isDark),
                      const SizedBox(height: 6),
                      _buildVerifyCodeButton(),
                    ],
                  ]
                  // 👤 Customer-only field
                  else if (_isSignUp && _selectedRole == 'customer') ...[
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'ناوی تەواو',
                      icon: Icons.person_outline_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 🔐 Password
                  _buildPasswordField(isDark),
                  const SizedBox(height: 28),

                  // 🚀 Submit
                  _buildSubmitButton(isDark),
                  const SizedBox(height: 16),

                  // 🔄 Toggle
                  _buildToggleMode(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Widgets
  // ═══════════════════════════════════════════════════════════
  Widget _buildLogo() {
    return Container(
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
          'assets/images/kalar.jpeg',
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
    );
  }

  Widget _buildRoleDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      dropdownColor: isDark ? AppColors.darkCard : AppColors.surface,
      decoration: _inputDecoration(
        label: 'جۆری ئەکاونت',
        icon: Icons.person_pin_outlined,
        isDark: isDark,
      ),
      items: const [
        DropdownMenuItem(
          value: 'customer',
          child: Text(
            '👤 هاوڵاتی (بەکارهێنەر)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DropdownMenuItem(
          value: 'admin',
          child: Text(
            '🏪 ئەدمین (خاوەن شوێن)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _selectedRole = v;
          _storeCodeVerified = false;
          _selectedStore = null;
          _storeCodeCtrl.clear();
        });
      },
    );
  }

  Widget _buildStoreSelector(bool isDark) {
    if (_loadingStores) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return DropdownButtonFormField<Map<String, dynamic>>(
      isExpanded: true,
      dropdownColor: isDark ? AppColors.darkCard : AppColors.surface,
      decoration: _inputDecoration(
        label: 'شوێنەکەت هەڵبژێرە *',
        icon: Icons.storefront_rounded,
        isDark: isDark,
      ),
      value: _selectedStore,
      items: _allStores.map((store) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: store,
          child: Text(
            '${store['name']} (${store['category'] ?? ''})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedStore = val;
          _storeCodeVerified = false;
          _storeCodeCtrl.clear();
        });
      },
    );
  }

  Widget _buildStoreCodeField(bool isDark) {
    return TextField(
      controller: _storeCodeCtrl,
      onChanged: (_) => setState(() => _storeCodeVerified = false),
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'کۆدی نهێنی شوێن *',
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surface,
        prefixIcon: const Icon(
          Icons.vpn_key_rounded,
          color: AppColors.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _storeCodeVerified
                ? Icons.check_circle_rounded
                : Icons.verified_outlined,
            color: _storeCodeVerified ? AppColors.green : AppColors.primary,
          ),
          onPressed: _verifyStoreCode,
        ),
      ),
    );
  }

  Widget _buildVerifyCodeButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _verifyStoreCode,
        icon: Icon(
          _storeCodeVerified
              ? Icons.check_circle_rounded
              : Icons.verified_rounded,
          color: _storeCodeVerified ? AppColors.green : AppColors.primary,
          size: 18,
        ),
        label: Text(
          _storeCodeVerified ? 'کۆد ڕاستە ✅' : 'پشتڕاستکردنەوەی کۆد',
          style: TextStyle(
            color: _storeCodeVerified ? AppColors.green : AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : AppColors.textTertiary,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surface,
      ),
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return TextField(
      controller: _passCtrl,
      obscureText: _obscurePass,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'پاسۆرد * (لانیکەم ٦ پیت)',
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePass
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surface,
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Text(
          _isSignUp ? 'دروستکردنی ئەکاونت' : 'چوونەژوورەوە',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleMode() {
    return TextButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _isSignUp = !_isSignUp);
      },
      child: Text(
        _isSignUp
            ? 'ئەکاونتت هەیە؟ بچۆ ژوورەوە'
            : 'ئەکاونتت نییە؟ دروستبکە',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white70 : AppColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : AppColors.surface,
      prefixIcon: Icon(icon, color: AppColors.primary),
    );
  }
}