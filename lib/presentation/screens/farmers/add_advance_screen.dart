import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Add Advance to Farmer Screen
class AddAdvanceScreen extends StatefulWidget {
  final String farmerId;
  final String farmerName;

  const AddAdvanceScreen({
    Key? key,
    required this.farmerId,
    required this.farmerName,
  }) : super(key: key);

  @override
  State<AddAdvanceScreen> createState() => _AddAdvanceScreenState();
}

class _AddAdvanceScreenState extends State<AddAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  static const _quickAmounts = [100000, 200000, 500000, 1000000];

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  double get _amount => double.tryParse(_amountController.text) ?? 0;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: DashPalette.green,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: DashPalette.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _saveAdvance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final batch = FirebaseFirestore.instance.batch();

      final advanceRef = FirebaseFirestore.instance
          .collection(AppConstants.advancesCollection)
          .doc();
      batch.set(advanceRef, {
        'farmerId': widget.farmerId,
        'farmerName': widget.farmerName,
        'amount': amount,
        'remainingAmount': amount,
        'notes': _notesController.text.trim(),
        'status': 'active', // active, fully_recovered, cancelled
        'advanceDate': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final farmerRef = FirebaseFirestore.instance
          .collection(AppConstants.farmersCollection)
          .doc(widget.farmerId);
      batch.update(farmerRef, {
        'totalAdvances': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final currentUser = AuthService.instance.currentUser;
      if (currentUser?.branchId != null) {
        NotificationService.instance.notifyAdvanceGiven(
          farmerName: widget.farmerName,
          amount: amount,
          branchId: currentUser!.branchId!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Advance of ${CurrencyFormatter.formatUGX(amount)} given successfully'),
            backgroundColor: DashPalette.greenDark,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: DashPalette.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  InputDecoration _dec(String label, IconData icon,
      {String? hint, Widget? suffix}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: DashPalette.muted, fontSize: 14),
      hintStyle: const TextStyle(color: DashPalette.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(
          color: DashPalette.greenDark, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: DashPalette.green, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: b(DashPalette.border),
      focusedBorder: b(DashPalette.green, 1.6),
      errorBorder: b(DashPalette.red),
      focusedErrorBorder: b(DashPalette.red, 1.6),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DashPalette.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E2217).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _farmerHeader() {
    final initial =
        widget.farmerName.isNotEmpty ? widget.farmerName[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DashPalette.ink, DashPalette.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Giving advance to',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.7))),
                const SizedBox(height: 3),
                Text(widget.farmerName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(t,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink)),
      );

  Widget _quickChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in _quickAmounts)
          ActionChip(
            label: Text(CurrencyFormatter.formatUGXCompact(v.toDouble()),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DashPalette.greenDark)),
            backgroundColor: DashPalette.greenSoft,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            onPressed: () => setState(() => _amountController.text = '$v'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: DashPalette.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DashPalette.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Give Advance',
            style: TextStyle(
                color: DashPalette.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final pad = c.maxWidth < 560 ? 14.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _farmerHeader(),
                      const SizedBox(height: 16),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Advance details'),

                            // Date
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              onTap: _selectDate,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: DashPalette.ink),
                              decoration: _dec(
                                'Advance date',
                                Icons.calendar_today_rounded,
                                suffix: const Icon(Icons.expand_more_rounded,
                                    color: DashPalette.muted),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(4, 6, 0, 0),
                              child: Text(
                                  'Change the date if the advance was given earlier.',
                                  style: TextStyle(
                                      fontSize: 12, color: DashPalette.muted)),
                            ),
                            const SizedBox(height: 18),

                            // Amount
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: DashPalette.ink),
                              decoration: _dec('Amount (UGX)',
                                  Icons.payments_outlined,
                                  hint: '0'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter amount';
                                }
                                final a = double.tryParse(value);
                                if (a == null || a <= 0) {
                                  return 'Please enter a valid amount';
                                }
                                return null;
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
                              child: Text(
                                amount > 0
                                    ? CurrencyFormatter.formatUGX(amount)
                                    : 'Pick a quick amount or type your own',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: amount > 0
                                        ? DashPalette.greenDark
                                        : DashPalette.muted),
                              ),
                            ),
                            _quickChips(),
                            const SizedBox(height: 18),

                            // Notes
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(
                                  fontSize: 15, color: DashPalette.ink),
                              decoration: _dec('Notes (optional)',
                                  Icons.sticky_note_2_outlined,
                                  hint: 'Reason, payment method, etc.'),
                            ),
                            const SizedBox(height: 18),

                            // Info
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: DashPalette.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: DashPalette.blue.withOpacity(0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: DashPalette.blue, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'This advance will be deducted automatically from future purchases.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: DashPalette.ink),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Save
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveAdvance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DashPalette.ink,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                DashPalette.ink.withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded,
                                  size: 22),
                          label: Text(
                            _isLoading
                                ? 'Saving...'
                                : (amount > 0
                                    ? 'Give ${CurrencyFormatter.formatUGXCompact(amount)}'
                                    : 'Give advance'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}