import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/phone_pin_auth.dart';

/// Login screen - phone number + PIN (email + password still available
/// through the "Sign in with email instead" link, e.g. for the admin account).
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Palette - Coffee Brown & Earth Green theme for agriculture
  static const Color _brown = Color(0xFF6D4C3D); // Coffee brown
  static const Color _brownDark = Color(0xFF4A342A); // Dark roast
  static const Color _earthGreen = Color(0xFF5D7C4F); // Natural earth green
  static const Color _ink = Color(0xFF2C1810); // Deep brown text
  static const Color _muted = Color(0xFF8B7355); // Light brown
  static const Color _fieldBg = Color(0xFFFAF8F6); // Cream
  static const Color _fieldLine = Color(0xFFE5DDD6); // Light tan

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _secretController = TextEditingController(); // PIN or password
  final _secretFocus = FocusNode();

  bool _usePhone = true; // phone + PIN (default) or email + password
  bool _isLoading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _idValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_checkId);
    _emailController.addListener(_checkId);
  }

  void _checkId() {
    final ok = _usePhone
        ? PhonePinAuth.isValidPhone(_phoneController.text)
        : RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(_emailController.text.trim());
    if (ok != _idValid) setState(() => _idValid = ok);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _secretController.dispose();
    _secretFocus.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _usePhone = !_usePhone;
      _secretController.clear();
      _obscure = true;
      _idValid = false;
    });
    _formKey.currentState?.reset();
    _checkId();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get phone and PIN
      final phone = _usePhone ? _phoneController.text.trim() : null;
      final email = !_usePhone ? _emailController.text.trim() : null;
      final pin = _secretController.text.trim();

      // Query Firestore for user with matching phone/email and PIN
      Query query = FirebaseFirestore.instance.collection('hansb_users');
      
      if (_usePhone) {
        query = query.where('phone', isEqualTo: phone);
      } else {
        query = query.where('email', isEqualTo: email);
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _showError(_usePhone 
            ? 'No account found for this phone number' 
            : 'No user found with this email');
        return;
      }

      // Check PIN/password
      final userDoc = snapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final storedPin = userData['pin']?.toString() ?? '';
      
      if (storedPin != pin) {
        _showError(_usePhone ? 'Incorrect PIN' : 'Incorrect password');
        return;
      }

      // Check if user is active
      final isActive = userData['isActive'] ?? userData['is_active'] ?? true;
      if (!isActive) {
        _showError('This account has been disabled');
        return;
      }

      // Create session in AuthService (without Firebase Auth)
      final user = AppUser(
        uid: userDoc.id,
        email: userData['email'] ?? userData['phone'] ?? '',
        displayName: userData['name'] ?? userData['display_name'] ?? 'User',
        role: _parseRole(userData['role']?.toString() ?? 'branchWorker'),
        branchId: userData['branch_id'],
        branchName: userData['branch_name'],
      );
      
      // Set current user in AuthService
      AuthService.instance.setCurrentUser(user);

      if (!mounted) return;

      // Navigate to dashboard
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  UserRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
      case 'super_admin':
      case 'admin':
        return UserRole.superAdmin;
      case 'branchmanager':
      case 'branch_manager':
      case 'manager':
        return UserRole.branchManager;
      default:
        return UserRole.branchWorker;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _brownDark,
        body: Stack(
          children: [
            // background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_brown, _brownDark],
                  ),
                ),
              ),
            ),
            // decorative circles
            Positioned(
              top: -140,
              left: -120,
              child: _circle(380, Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              bottom: -180,
              right: -140,
              child: _circle(460, Colors.white.withOpacity(0.06)),
            ),
            Positioned(
              top: 90,
              right: 90,
              child: _circle(26, _earthGreen.withOpacity(0.55)),
            ),
            Positioned(
              bottom: 110,
              left: 100,
              child: _circle(18, Colors.white.withOpacity(0.18)),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) => Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - t)),
                              child: child,
                            ),
                          ),
                          child: _card(),
                        ),
                        const SizedBox(height: 22),
                        // Copyright FIRST, then powered by
                        Text(
                          '© ${DateTime.now().year} ${AppConstants.companyNameShort}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.55),
                            ),
                            children: const [
                              TextSpan(text: 'Powered by '),
                              TextSpan(
                                text: 'Infinitech Innovations Ltd',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ───────────────────────── Card ─────────────────────────

  Widget _tick() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _idValid ? 1 : 0,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: _brown,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo + brand
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _fieldLine),
                  boxShadow: [
                    BoxShadow(
                      color: _brown.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Image.asset(
                    'assets/logo.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.coffee, size: 40, color: _brown),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppConstants.companyNameShort.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: _brown,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _usePhone
                    ? 'Sign in with your phone number and PIN'
                    : 'Sign in with your email and password',
                key: ValueKey<bool>(_usePhone),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: _muted),
              ),
            ),
            const SizedBox(height: 28),

            // Identifier: phone or email
            if (_usePhone)
              _field(
                key: const ValueKey('phone'),
                controller: _phoneController,
                hint: 'Phone number (e.g. 0700 000 000)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _secretFocus.requestFocus(),
                suffix: _tick(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (!PhonePinAuth.isValidPhone(value)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              )
            else
              _field(
                key: const ValueKey('email'),
                controller: _emailController,
                hint: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _secretFocus.requestFocus(),
                suffix: _tick(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 14),

            // PIN or password
            _field(
              key: ValueKey<bool>(_usePhone),
              controller: _secretController,
              focusNode: _secretFocus,
              hint: _usePhone ? 'PIN (4-6 digits)' : 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              keyboardType:
                  _usePhone ? TextInputType.number : TextInputType.text,
              inputFormatters: _usePhone
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                          PhonePinAuth.maxPinLength),
                    ]
                  : null,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              suffix: IconButton(
                splashRadius: 20,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: _muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _usePhone
                      ? 'Please enter your PIN'
                      : 'Please enter your password';
                }
                if (_usePhone && !PhonePinAuth.isValidPin(value)) {
                  return 'PIN must be ${PhonePinAuth.minPinLength}-${PhonePinAuth.maxPinLength} digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Remember me / forgot
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            activeColor: _brown,
                            side: const BorderSide(
                                color: Color(0xFFB7C3CF), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(fontSize: 13.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_usePhone
                            ? 'Contact admin to reset your PIN'
                            : 'Contact admin to reset your password'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _usePhone ? 'Forgot PIN?' : 'Forgot password?',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _earthGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sign in
            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _brown.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brown,
                  disabledBackgroundColor: _brown.withOpacity(0.7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          key: ValueKey('label'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Switch login method
            TextButton(
              onPressed: _isLoading ? null : _switchMode,
              child: Text(
                _usePhone
                    ? 'Sign in with email instead'
                    : 'Sign in with phone number & PIN',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _earthGreen,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Need an account
            const Divider(height: 1, color: _fieldLine),
            const SizedBox(height: 14),
            const Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13.5, color: _muted, height: 1.5),
                children: [
                  TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: 'Contact your administrator',
                    style: TextStyle(
                      color: _earthGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: ' to create one.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Pill field ─────────────────────────

  Widget _field({
    Key? key,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: _ink,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9AA7B4)),
        prefixIcon: Icon(icon, size: 20, color: _muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        enabledBorder: border(_fieldLine),
        border: border(_fieldLine),
        focusedBorder: border(_brown, 1.8),
        errorBorder: border(Colors.red.shade400),
        focusedErrorBorder: border(Colors.red.shade600, 1.8),
        errorStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}