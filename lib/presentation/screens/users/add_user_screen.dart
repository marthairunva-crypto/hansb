import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Add User Screen - create a new user account (full page form)
class AddUserScreen extends StatefulWidget {
  const AddUserScreen({Key? key}) : super(key: key);

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _toast(String message, {Color color = DashPalette.greenDark}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pinController.text != _confirmPinController.text) {
      _toast('PINs do not match', color: DashPalette.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if phone already exists
      final existingUser = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('phone', isEqualTo: _phoneController.text.trim())
          .get();

      if (existingUser.docs.isNotEmpty) {
        _toast('Phone number already registered', color: DashPalette.red);
        return;
      }

      // Create user
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'pin': _pinController.text, // In production, hash this!
        'role': _selectedRole,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _toast('User created successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      _toast('Error: $e', color: DashPalette.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  static const TextStyle _inputStyle =
      TextStyle(fontSize: 14.5, color: DashPalette.ink);

  InputDecoration _decoration(IconData icon, {String? hint, Widget? suffix}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA79F), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: DashPalette.muted),
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: border(DashPalette.border),
      focusedBorder: border(DashPalette.green, 1.6),
      errorBorder: border(DashPalette.red),
      focusedErrorBorder: border(DashPalette.red, 1.6),
    );
  }

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DashPalette.ink,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _eye() => IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: DashPalette.muted,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DashPalette.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create user account',
          style: TextStyle(
            color: DashPalette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DashPalette.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DashPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0E2217).withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: DashPalette.greenSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded,
                              color: DashPalette.greenDark),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: DashPalette.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'They will sign in with their phone number and PIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DashPalette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _labeled(
                      'Full name *',
                      TextFormField(
                        controller: _nameController,
                        style: _inputStyle,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(Icons.person_outline_rounded,
                            hint: 'e.g. Jane Nakato'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter name'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _labeled(
                      'Phone number *',
                      TextFormField(
                        controller: _phoneController,
                        style: _inputStyle,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        decoration: _decoration(Icons.phone_outlined,
                            hint: '0700 XXX XXX'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter phone number'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _labeled(
                      'Role *',
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        decoration: _decoration(Icons.security_rounded),
                        items: const [
                          DropdownMenuItem(
                              value: 'user',
                              child: Text('User (Regular Staff)')),
                          DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin (Full Access)')),
                        ],
                        onChanged: (v) => setState(() => _selectedRole = v!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _labeled(
                      'PIN (4-6 digits) *',
                      TextFormField(
                        controller: _pinController,
                        obscureText: _obscure,
                        keyboardType: TextInputType.number,
                        style: _inputStyle,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: _decoration(Icons.lock_outline_rounded,
                            hint: '4 to 6 digits', suffix: _eye()),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter PIN';
                          if (v.length < 4) return 'PIN must be at least 4 digits';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _labeled(
                      'Confirm PIN *',
                      TextFormField(
                        controller: _confirmPinController,
                        obscureText: _obscure,
                        keyboardType: TextInputType.number,
                        style: _inputStyle,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: _decoration(Icons.lock_reset_rounded,
                            hint: 'Re-enter the PIN'),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please confirm PIN'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _saveUser,
                        style: FilledButton.styleFrom(
                          backgroundColor: DashPalette.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              DashPalette.green.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w800),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text('Create account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}