// lib/screens/auth/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/password_hasher.dart';

/// 🔐 شاشەی چوونەژوورەوە و دروستکردنی ئەکاونت — SECURE EDITION
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
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
  // 🏪 هێنانی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchStores() async {
    setState(() => _loadingStores = true);
    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select('id, name, category, invite_code')
          .not('invite_code', 'is', null)
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

  // ═══════════════════════════════════════════════════════════
  // 🔔 SnackBar Helper
  // ═══════════════════════════════════════════════════════════
  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

    // ═══ پشکنینەکان ═══
    if (phone.isEmpty || pass.isEmpty) {
      _showSnackBar('مۆبایل و پاسۆرد پێویستە ⚠', Colors.orange);
      return;
    }
    if (pass.length < 8) {
      _showSnackBar('پاسۆرد دەبێت لانیکەم ٨ پیت بێت ⚠', Colors.orange);
      return;
    }
    if (phone.length < 10) {
      _showSnackBar('ژمارەی مۆبایل دروست نییە ⚠', Colors.orange);
      return;
    }

    // ═══ پشکنینی SignUp ═══
    if (_isSignUp) {
      if (_selectedRole == 'vendor' || _selectedRole == 'department') {
        if (_selectedStore == null) {
          _showSnackBar('تکایە شوێنەکەت هەڵبژێرە 🏪', Colors.orange);
          return;
        }
        if (_storeCodeCtrl.text.trim().isEmpty) {
          _showSnackBar('تکایە کۆدی شوێن بنووسە 🔑', Colors.orange);
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

    try {
      if (_isSignUp) {
        await _handleSignUp(phone, pass, name);
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
      ) async {
    // ═══ ١. پشکنینی دووبارەبوون ═══
    try {
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
    } catch (e) {
      _showSnackBar('هەڵە لە پشکنین: $e', Colors.red);
      return;
    }

    // ═══ ٢. بۆ ڤێندەر / فەرمانگە — بە Edge Function ═══
    if (_selectedRole == 'vendor' || _selectedRole == 'department') {
      await _handleVendorSignUp(phone, pass, name);
      return;
    }

    // ═══ ٣. بۆ کڕیار — بە RLS ═══
    await _handleCustomerSignUp(phone, pass, name);
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Vendor SignUp — بە Edge Function
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleVendorSignUp(
      String phone,
      String pass,
      String name,
      ) async {
    try {
      final hashedPass = await PasswordHasher.hash(pass);

      // ⭐ ١. دروستکردنی ئەکاونت لە Supabase Auth
      try {
        final fakeEmail = '$phone@kalar-guide.com';
        await Supabase.instance.client.auth.signUp(
          email: fakeEmail,
          password: pass,
        );
        debugPrint('✅ Supabase Auth: Vendor user created');
      } catch (authError) {
        debugPrint('⚠️ Auth signup error: $authError');
      }

      // ⭐ ٢. بانگکردنی Edge Function بۆ تۆمارکردن لە داتابەیس
      final response = await Supabase.instance.client.functions.invoke(
        'register-vendor',
        body: {
          'storeId': _selectedStore!['id'],
          'name': name,
          'phone': phone,
          'password': hashedPass,
          'inviteCode': _storeCodeCtrl.text.trim(),
        },
      );

      if (response.status != 200) {
        final error = response.data?['error']?.toString() ??
            'هەڵە لە ناردنی داواکاری';
        _showSnackBar(error, Colors.red);
        return;
      }

      _showSnackBar(
        response.data?['message']?.toString() ??
            'داواکاریت نێردرا — چاوەڕوانی پەسەندی ئەدمین بە ⏳',
        Colors.green,
      );

      setState(() {
        _isSignUp = false;
        _selectedStore = null;
        _storeCodeCtrl.clear();
        _phoneCtrl.clear();
        _passCtrl.clear();
        _nameCtrl.clear();
      });
    } catch (e) {
      debugPrint('❌ Vendor signup error: $e');
      _showSnackBar('هەڵە: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 👤 Customer SignUp
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleCustomerSignUp(
      String phone,
      String pass,
      String name,
      ) async {
    try {
      final hashedPass = await PasswordHasher.hash(pass);

      // ⭐ ١. دروستکردنی ئەکاونت لە Supabase Auth
      try {
        final fakeEmail = '$phone@kalar-guide.com';
        await Supabase.instance.client.auth.signUp(
          email: fakeEmail,
          password: pass,
        );
        debugPrint('✅ Supabase Auth: Customer user created');
      } catch (authError) {
        debugPrint('⚠️ Auth signup error: $authError');
      }

      // ⭐ ٢. تۆمارکردن لە داتابەیس
      await Supabase.instance.client.from('app_users').insert({
        'name': name,
        'phone': phone,
        'password': hashedPass,
        'role': 'customer',
        'is_approved': true,
      });

      _showSnackBar(
        'ئەکاونتەکەت دروستکرا — بچۆ ژوورەوە ✅',
        Colors.green,
      );

      setState(() {
        _isSignUp = false;
        _nameCtrl.clear();
        _passCtrl.clear();
      });
    } catch (e) {
      debugPrint('❌ Customer signup error: $e');
      _showSnackBar('هەڵە: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔑 چوونەژوورەوە — ⭐ نوێکراو بۆ چارەسەری RLS
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleLogin(String phone, String pass) async {
    try {
      // ═══ ١. Login لە AuthSessionManager (سیستەمی کۆن) ═══
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
        if (mounted) _showPendingDialog();
        return;
      }

      // ═══ ٢. تۆمارکردن لە Supabase Auth (سیستەمی نوێ) ═══
      // ⭐ ئەمە زۆر گرنگە بۆ ئەوەی RLS کار بکات
      try {
        final fakeEmail = '$phone@kalar-guide.com';

        debugPrint('🔐 Supabase Auth: Attempting login for $fakeEmail');

        // سەرەتا هەوڵبدە بچۆ ژوورەوە
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: fakeEmail,
            password: pass,
          );
          debugPrint('✅ Supabase Auth: Login successful');
        } on AuthException catch (e) {
          debugPrint('⚠️ Supabase Auth error: ${e.message}');

          // ئەگەر بەکارهێنەرەکە لە Auth دا نەبوو، دروستی بکە
          if (e.message.contains('Invalid login credentials')) {
            try {
              await Supabase.instance.client.auth.signUp(
                email: fakeEmail,
                password: pass,
              );
              debugPrint('✅ Supabase Auth: New user created');

              // دوای دروستکردن، دووبارە بچۆ ژوورەوە
              await Supabase.instance.client.auth.signInWithPassword(
                email: fakeEmail,
                password: pass,
              );
              debugPrint('✅ Supabase Auth: Login after signup successful');
            } catch (signUpError) {
              debugPrint('❌ Supabase Auth signup error: $signUpError');
            }
          }
        }

        // پشکنین بکە ئەگەر بەکارهێنەرەکە بە ڕاستی چووەتە ژوورەوە
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          debugPrint('👤 Supabase User ID: ${currentUser.id}');
        } else {
          debugPrint('⚠️ Supabase User is still NULL!');
        }
      } catch (authError) {
        debugPrint('❌ Supabase Auth setup error: $authError');
      }

      // ✅ سەرکەوتوو
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('بەخێربێیت! ✅', Colors.green);
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      _showSnackBar('هەڵە: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Pending Dialog
  // ═══════════════════════════════════════════════════════════
  void _showPendingDialog() {
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
                  // ═══ لۆگۆ ═══
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

                  // ═══ SignUp fields ═══
                  if (_isSignUp) ...[
                    _buildRoleDropdown(),
                    const SizedBox(height: 14),

                    if (_selectedRole == 'vendor' ||
                        _selectedRole == 'department')
                      ..._buildVendorFields()
                    else
                      ..._buildCustomerFields(),
                  ],

                  // ═══ مۆبایل ═══
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

                  // ═══ پاسۆرد ═══
                  TextField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'پاسۆرد * (لانیکەم ٨ پیت)',
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

                  // ═══ دوگمەی ناردن ═══
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

                  // ═══ گۆڕین ═══
                  TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _selectedStore = null;
                      _storeCodeCtrl.clear();
                    }),
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

  // ═══════════════════════════════════════════════════════════
  // 🎨 Field Builders
  // ═══════════════════════════════════════════════════════════
  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
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
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _selectedRole = v;
          _selectedStore = null;
          _storeCodeCtrl.clear();
        });
      },
    );
  }

  List<Widget> _buildVendorFields() {
    return [
      if (_loadingStores)
        const Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        )
      else
        DropdownButtonFormField<Map<String, dynamic>>(
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
            _storeCodeCtrl.clear();
          }),
        ),
      const SizedBox(height: 14),

      if (_selectedStore != null) ...[
        TextField(
          controller: _storeCodeCtrl,
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
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '💡 کۆدەکە لەلایەن ئەدمین پێتدراوە. کاتێک داواکاریت نێردرا، '
                'چاوەڕوانی پەسەندی ئەدمین بە.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
    ];
  }

  List<Widget> _buildCustomerFields() {
    return [
      TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(
          labelText: 'ناوی تەواو *',
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
    ];
  }
}