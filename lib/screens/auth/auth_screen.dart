// lib/screens/auth/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';

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
  final _pass2Ctrl = TextEditingController();
  final _storeCodeCtrl = TextEditingController();

  String _selectedRole = 'customer';
  bool _isSignUp = false;
  bool _obscurePass = true;
  bool _loading = false;
  bool _googleLoading = false;

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
    _pass2Ctrl.dispose();
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
      _showSnackBar(tr('تکایە سەرەتا شوێنێک هەڵبژێرە'), AppColors.orange);
      return;
    }

    final enteredCode = _storeCodeCtrl.text.trim();
    if (enteredCode.isEmpty) {
      _showSnackBar(tr('تکایە کۆدەکە بنووسە'), AppColors.orange);
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
        isValid ? tr('کۆد ڕاستە ✅') : tr('کۆد هەڵەیە ❌'),
        isValid ? AppColors.green : AppColors.red,
      );
    } catch (e) {
      debugPrint('❌ verify_vendor_code: $e');
      if (mounted) {
        setState(() => _storeCodeVerified = false);
        _showSnackBar(tr('پشکنینی کۆد سەرنەکەوت، دووبارە هەوڵ بدەرەوە'), AppColors.red);
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
            tr(msg),
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
      _showSnackBar(tr('مۆبایل و پاسۆرد پێویستە ⚠'), AppColors.orange);
      return;
    }
    // تەنها لە تۆمارکردندا درێژی پشکنین دەکرێت، بۆ ئەوەی بەکارهێنەرە کۆنەکان
    // (کە پاسۆردی ٦-٧ پیتییان هەیە) هێشتا بتوانن بچنە ژوورەوە.
    if (_isSignUp && pass.length < _minPasswordLength) {
      _showSnackBar(
        trf('پاسۆرد دەبێت لانیکەم {0} پیت بێت ⚠', [PlaceDisplay.digits(_minPasswordLength)]),
        AppColors.orange,
      );
      return;
    }
    if (_isSignUp && pass != _pass2Ctrl.text.trim()) {
      _showSnackBar(tr('پاسۆردەکان وەک یەک نین ⚠'), AppColors.orange);
      return;
    }
    if (phone.length < 10) {
      _showSnackBar(tr('ژمارەی مۆبایل دروست نییە ⚠'), AppColors.orange);
      return;
    }

    if (_isSignUp) {
      if (_selectedRole == 'admin') {
        if (_selectedStore == null) {
          _showSnackBar(tr('تکایە شوێنەکەت هەڵبژێرە 🏪'), AppColors.orange);
          return;
        }
        if (!_storeCodeVerified) {
          _showSnackBar(tr('تکایە کۆدی شوێن پشتڕاست بکەرەوە 🔑'), AppColors.orange);
          return;
        }
      } else {
        if (name.isEmpty) {
          _showSnackBar(tr('ناوی تەواو پێویستە'), AppColors.orange);
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
        _showSnackBar(tr('هەڵەیەک ڕوویدا، تکایە دووبارە هەوڵ بدەرەوە'), AppColors.red);
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
        _showSnackBar(tr('ئەم ژمارەیە پێشتر تۆمار کراوە ⚠'), AppColors.orange);
        return;
      }
      if (res != 'ok') {
        setState(() => _storeCodeVerified = false);
        _showSnackBar(tr('کۆدی شوێن هەڵەیە ❌'), AppColors.red);
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
      _showSnackBar(tr('ئەم ژمارەیە پێشتر تۆمار کراوە ⚠'), AppColors.orange);
      return;
    }
    if (res != 'ok') {
      _showSnackBar(tr('تۆمارکردن سەرنەکەوت'), AppColors.red);
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
      _showSnackBar(tr('مۆبایل یان پاسۆرد هەڵەیە ❌'), AppColors.red);
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
  // 🔵 Google
  // ═══════════════════════════════════════════════════════════
  Future<void> _signInWithGoogle() async {
    if (_googleLoading || _loading) return;
    HapticFeedback.selectionClick();
    setState(() => _googleLoading = true);
    final result = await GoogleAuthService.signIn();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    switch (result) {
      case GoogleLoginResult.ok:
        Navigator.pop(context);
      case GoogleLoginResult.pending:
        await _showPendingDialog();
      case GoogleLoginResult.cancelled:
        break;
      default:
        _showSnackBar(result.message, AppColors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ Dialog بۆ ڤێندەری چاوەڕوان
  // ═══════════════════════════════════════════════════════════
  Future<void> _showPendingDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: AppColors.orange),
              const SizedBox(width: 8),
              Text(
                tr('چاوەڕوان بە ⏳'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Text(
            tr('هێشتا داواکاریت لەلایەن ئەدمینەوە پەسەند نەکراوە.\n\nتکایە چاوەڕوان بە تا پەسەند دەکرێیت.'),
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                tr('باشە'),
                style: const TextStyle(fontWeight: FontWeight.w900),
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
    final bgColor = isDark ? AppColors.darkBackground : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);
    final showGoogle = GoogleAuthService.isAvailable &&
        (!_isSignUp || _selectedRole == 'customer');

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── دوگمەی گەڕانەوە ──
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
                  child: IconButton(
                    tooltip: tr('گەڕانەوە'),
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _buildLogo(),
                      ),
                      const SizedBox(height: 22),
                      // ── ناونیشان ──
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.35,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                          children: [
                            TextSpan(
                              text: tr(_isSignUp ? 'دروستکردنی ئەکاونت لە' : 'بەخێربێیتەوە بۆ'),
                            ),
                            const TextSpan(text: '\n'),
                            TextSpan(
                              text: tr('ڕێبەری کەلار'),
                              style: const TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(_isSignUp
                            ? 'چەند زانیارییەکی کەم، پاشان ئامادەیت'
                            : 'بۆ بەردەوامبوون بچۆ ژوورەوە'),
                        style: TextStyle(fontSize: 14, color: subColor, height: 1.5),
                      ),
                      const SizedBox(height: 26),

                      // ── Google ──
                      if (showGoogle) ...[
                        _buildGoogleButton(isDark),
                        const SizedBox(height: 18),
                        _buildOrDivider(subColor),
                        const SizedBox(height: 18),
                      ],

                      // 🎭 جۆری ئەکاونت
                      if (_isSignUp) ...[
                        _buildRoleCards(isDark),
                        const SizedBox(height: 16),
                      ],

                      // 📱 Phone
                      _buildTextField(
                        controller: _phoneCtrl,
                        label: tr('ژمارەی مۆبایل'),
                        hint: '0770 000 0000',
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      // 🏪 خاوەن شوێن
                      if (_isSignUp && _selectedRole == 'admin') ...[
                        _buildStoreSelector(isDark),
                        const SizedBox(height: 14),
                        if (_selectedStore != null) ...[
                          _buildStoreCodeField(isDark),
                          const SizedBox(height: 6),
                          _buildVerifyCodeButton(),
                        ],
                      ]
                      // 👤 بەکارهێنەر
                      else if (_isSignUp && _selectedRole == 'customer') ...[
                        _buildTextField(
                          controller: _nameCtrl,
                          label: tr('ناوی تەواو'),
                          icon: Icons.person_outline_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 🔐 Password
                      _buildPasswordField(isDark),
                      if (_isSignUp) ...[
                        const SizedBox(height: 14),
                        _buildPasswordField(isDark, confirm: true),
                      ],
                      const SizedBox(height: 26),

                      // 🚀 Submit
                      _buildSubmitButton(isDark),
                    ],
                  ),
                ),
              ),

              // 🔄 Toggle (خوارەوەی شاشە)
              _buildToggleMode(isDark),
            ],
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/kalar.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.primary,
            child: const Icon(Icons.explore_rounded, size: 34, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _googleLoading || _loading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
          side: BorderSide(color: _hairline(isDark)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _googleLoading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleMark(),
                  const SizedBox(width: 12),
                  Text(
                    tr('بەردەوامبوون بە Google'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOrDivider(Color color) {
    return Row(
      children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            tr('یان بە ژمارەی مۆبایل'),
            style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
      ],
    );
  }

  Widget _buildRoleCards(bool isDark) {
    Widget card(String value, IconData icon, String title, String sub) {
      final selected = _selectedRole == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (selected) return;
            HapticFeedback.selectionClick();
            setState(() {
              _selectedRole = value;
              _storeCodeVerified = false;
              _selectedStore = null;
              _storeCodeCtrl.clear();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.06)
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : _hairline(isDark),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? AppColors.primary : AppColors.toneSlate, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          )),
                      Text(tr(sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card('customer', Icons.person_rounded, 'بەکارهێنەر', 'بۆ هاوڵاتیان'),
        const SizedBox(width: 10),
        card('admin', Icons.storefront_rounded, 'خاوەن شوێن', 'پێویستی بە کۆدە'),
      ],
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
        label: tr('شوێنەکەت هەڵبژێرە *'),
        icon: Icons.storefront_rounded,
        isDark: isDark,
      ),
      initialValue: _selectedStore,
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
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: tr('کۆدی نهێنی شوێن *'),
        icon: Icons.vpn_key_rounded,
        isDark: isDark,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _storeCodeVerified ? Icons.check_circle_rounded : Icons.verified_outlined,
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
          tr(_storeCodeVerified ? 'کۆد ڕاستە ✅' : 'پشتڕاستکردنەوەی کۆد'),
          style: TextStyle(
            color: _storeCodeVerified ? AppColors.green : AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Color _hairline(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);

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
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(label: label, icon: icon, isDark: isDark).copyWith(hintText: hint),
    );
  }

  Widget _buildPasswordField(bool isDark, {bool confirm = false}) {
    return TextField(
      controller: confirm ? _pass2Ctrl : _passCtrl,
      obscureText: _obscurePass,
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: confirm
            ? tr('دووبارەکردنەوەی پاسۆرد')
            : (_isSignUp
                ? trf('پاسۆرد (لانیکەم {0} پیت)', [PlaceDisplay.digits(_minPasswordLength)])
                : tr('پاسۆرد')),
        icon: Icons.lock_outline_rounded,
        isDark: isDark,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
          ),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
          tr(_isSignUp ? 'دروستکردنی ئەکاونت' : 'چوونەژوورەوە'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleMode(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tr(_isSignUp ? 'ئەکاونتت هەیە؟' : 'ئەکاونتت نییە؟'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isSignUp = !_isSignUp;
                _pass2Ctrl.clear();
              });
            },
            child: Text(
              tr(_isSignUp ? 'چوونەژوورەوە' : 'دروستکردنی ئەکاونت'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : Colors.white,
      prefixIcon: Icon(icon, color: isDark ? Colors.white54 : const Color(0xFF94A3B8), size: 21),
      border: border(_hairline(isDark)),
      enabledBorder: border(_hairline(isDark)),
      focusedBorder: border(AppColors.primary, 1.6),
    );
  }
}

/// نیشانەی «G»ی Google بە چوار ڕەنگەکەی (بێ وێنە)
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.2;
    final rect = Rect.fromCircle(center: Offset(w / 2, w / 2), radius: (w - stroke) / 2);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.1415926535 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335))); // سوور
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05))); // زەرد
    canvas.drawArc(rect, 130 * deg, -90 * deg, false, p(const Color(0xFF34A853))); // سەوز
    canvas.drawArc(rect, 40 * deg, -80 * deg, false, p(const Color(0xFF4285F4))); // شین
    canvas.drawLine(
      Offset(w / 2, w / 2),
      Offset(w - stroke / 2, w / 2),
      p(const Color(0xFF4285F4)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
