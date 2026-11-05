import 'package:flutter/material.dart';
import '../../../data/models/branch.dart';
import '../../../domain/services/branch_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Create / edit a branch (shown inside a dialog).
class BranchFormScreen extends StatefulWidget {
  final Branch? branch;

  const BranchFormScreen({
    Key? key,
    this.branch,
  }) : super(key: key);

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final BranchService _branchService = BranchService();

  late TextEditingController _branchCodeController;
  late TextEditingController _branchNameController;
  late TextEditingController _locationController;
  late TextEditingController _addressController;
  late TextEditingController _managerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;

  String _status = 'ACTIVE';
  bool _isHeadOffice = false;
  bool _isLoading = false;

  bool get isEditing => widget.branch != null;

  @override
  void initState() {
    super.initState();

    _branchCodeController =
        TextEditingController(text: widget.branch?.branchCode ?? '');
    _branchNameController =
        TextEditingController(text: widget.branch?.branchName ?? '');
    _locationController =
        TextEditingController(text: widget.branch?.location ?? '');
    _addressController =
        TextEditingController(text: widget.branch?.address ?? '');
    _managerNameController =
        TextEditingController(text: widget.branch?.managerName ?? '');
    _phoneController = TextEditingController(text: widget.branch?.phone ?? '');
    _emailController = TextEditingController(text: widget.branch?.email ?? '');
    _notesController = TextEditingController(text: widget.branch?.notes ?? '');

    if (widget.branch != null) {
      _status = widget.branch!.status;
      _isHeadOffice = widget.branch!.isHeadOffice;
    } else {
      _generateBranchCode();
    }
  }

  Future<void> _generateBranchCode() async {
    try {
      final branches = await _branchService.getAllBranches();
      final newCode = 'BR${(branches.length + 1).toString().padLeft(3, '0')}';
      if (!mounted) return;
      setState(() => _branchCodeController.text = newCode);
    } catch (e) {
      if (!mounted) return;
      setState(() => _branchCodeController.text = 'BR001');
    }
  }

  @override
  void dispose() {
    _branchCodeController.dispose();
    _branchNameController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _managerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _toast(String message, {Color color = DashPalette.greenDark}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final branch = Branch(
        id: widget.branch?.id,
        branchCode: _branchCodeController.text.trim(),
        branchName: _branchNameController.text.trim(),
        location: _nullIfEmpty(_locationController),
        address: _nullIfEmpty(_addressController),
        managerName: _nullIfEmpty(_managerNameController),
        phone: _nullIfEmpty(_phoneController),
        email: _nullIfEmpty(_emailController),
        status: _status,
        isHeadOffice: _isHeadOffice,
        notes: _nullIfEmpty(_notesController),
        createdAt: widget.branch?.createdAt ?? DateTime.now(),
      );

      if (isEditing) {
        await _branchService.updateBranch(branch);
      } else {
        await _branchService.createBranch(branch);
      }

      if (!mounted) return;
      _toast('Branch ${isEditing ? 'updated' : 'created'} successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Error: $e', color: DashPalette.red);
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 560;
      final pad = wide ? 28.0 : 20.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(pad),
          const Divider(height: 1, color: DashPalette.border),
          Flexible(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 22, pad, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Basic information'),
                    _twoCols(wide, [
                      _labeled(
                        'Branch code',
                        required: true,
                        child: TextFormField(
                          controller: _branchCodeController,
                          readOnly: !isEditing,
                          textCapitalization: TextCapitalization.characters,
                          style: _inputStyle,
                          decoration: _decoration(
                            icon: Icons.qr_code_2_rounded,
                            hint: 'Auto-generated',
                            locked: !isEditing,
                            suffix: isEditing
                                ? null
                                : const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: _AutoBadge(),
                                  ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Branch code is required'
                              : null,
                        ),
                      ),
                      _labeled(
                        'Branch name',
                        required: true,
                        child: TextFormField(
                          controller: _branchNameController,
                          style: _inputStyle,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.storefront_rounded,
                            hint: 'e.g. Kisoro Branch',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Branch name is required'
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 26),
                    _sectionTitle('Location & contact'),
                    _twoCols(wide, [
                      _labeled(
                        'Location',
                        child: TextFormField(
                          controller: _locationController,
                          style: _inputStyle,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.location_on_outlined,
                            hint: 'e.g. Kisoro Town',
                          ),
                        ),
                      ),
                      _labeled(
                        'Manager name',
                        child: TextFormField(
                          controller: _managerNameController,
                          style: _inputStyle,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.person_outline_rounded,
                            hint: 'Full name',
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _twoCols(wide, [
                      _labeled(
                        'Phone number',
                        child: TextFormField(
                          controller: _phoneController,
                          style: _inputStyle,
                          keyboardType: TextInputType.phone,
                          decoration: _decoration(
                            icon: Icons.phone_outlined,
                            hint: 'e.g. 0772 000 000',
                          ),
                        ),
                      ),
                      _labeled(
                        'Email',
                        child: TextFormField(
                          controller: _emailController,
                          style: _inputStyle,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decoration(
                            icon: Icons.mail_outline_rounded,
                            hint: 'branch@company.com',
                          ),
                          validator: (v) {
                            if (v != null &&
                                v.trim().isNotEmpty &&
                                !v.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _labeled(
                      'Full address',
                      child: TextFormField(
                        controller: _addressController,
                        style: _inputStyle,
                        maxLines: 2,
                        decoration: _decoration(
                          icon: Icons.home_outlined,
                          hint: 'Street, village, district',
                          topAlignIcon: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _sectionTitle('Settings'),
                    _labeled('Status', child: _statusPicker()),
                    const SizedBox(height: 16),
                    _headOfficeTile(),
                    const SizedBox(height: 16),
                    _labeled(
                      'Notes',
                      child: TextFormField(
                        controller: _notesController,
                        style: _inputStyle,
                        maxLines: 3,
                        decoration: _decoration(
                          icon: Icons.sticky_note_2_outlined,
                          hint: 'Anything worth remembering about this branch',
                          topAlignIcon: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: DashPalette.border),
          _footer(pad),
        ],
      );
    });
  }

  // ───────────────────────── Pieces ─────────────────────────

  Widget _header(double pad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 20, 14, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: DashPalette.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.add_business_rounded,
              color: DashPalette.greenDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit branch' : 'Add new branch',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEditing
                      ? 'Update the details of this branch'
                      : 'Fill in the details to register a new branch',
                  style: const TextStyle(
                    fontSize: 13,
                    color: DashPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                _isLoading ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: DashPalette.muted),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _footer(double pad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _isLoading ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: DashPalette.ink,
                side: const BorderSide(color: DashPalette.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isLoading ? null : _saveBranch,
              style: FilledButton.styleFrom(
                backgroundColor: DashPalette.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: DashPalette.green.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Text(isEditing ? 'Update branch' : 'Create branch'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: DashPalette.muted,
        ),
      ),
    );
  }

  Widget _labeled(String label, {required Widget child, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DashPalette.ink,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: DashPalette.red),
                  ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _twoCols(bool wide, List<Widget> children) {
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  static const TextStyle _inputStyle =
      TextStyle(fontSize: 14.5, color: DashPalette.ink);

  InputDecoration _decoration({
    required IconData icon,
    String? hint,
    bool locked = false,
    bool topAlignIcon = false,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA79F), fontSize: 14),
      prefixIcon: Padding(
        padding: EdgeInsets.only(bottom: topAlignIcon ? 28 : 0),
        child: Icon(icon, size: 20, color: DashPalette.muted),
      ),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
      isDense: true,
      filled: true,
      fillColor: locked ? const Color(0xFFF3F6F4) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: border(DashPalette.border),
      focusedBorder: border(DashPalette.green, 1.6),
      errorBorder: border(DashPalette.red),
      focusedErrorBorder: border(DashPalette.red, 1.6),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _statusPicker() {
    Widget pill(String value, String label, IconData icon, Color color) {
      final selected = _status == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _status = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : DashPalette.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: selected ? color : DashPalette.muted),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : DashPalette.muted,
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
        pill('ACTIVE', 'Active', Icons.check_circle_outline_rounded,
            DashPalette.green),
        const SizedBox(width: 12),
        pill('INACTIVE', 'Inactive', Icons.pause_circle_outline_rounded,
            DashPalette.amber),
      ],
    );
  }

  Widget _headOfficeTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _isHeadOffice = !_isHeadOffice),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isHeadOffice ? DashPalette.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHeadOffice ? DashPalette.green : DashPalette.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DashPalette.greenDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.business_rounded,
                  size: 20, color: DashPalette.greenDark),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Head office',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DashPalette.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mark this branch as the main branch',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: DashPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isHeadOffice,
              onChanged: (v) => setState(() => _isHeadOffice = v),
              activeColor: Colors.white,
              activeTrackColor: DashPalette.green,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCBD3CE),
              trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoBadge extends StatelessWidget {
  const _AutoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: DashPalette.greenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_awesome, size: 13, color: DashPalette.greenDark),
          SizedBox(width: 4),
          Text(
            'Auto',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: DashPalette.greenDark,
            ),
          ),
        ],
      ),
    );
  }
}