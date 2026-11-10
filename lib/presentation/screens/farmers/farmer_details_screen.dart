import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../home/dashboard_home_new.dart' show DashPalette;
import 'add_advance_screen.dart';

/// Farmer Details Screen - View farmer information and transactions
class FarmerDetailsScreen extends StatefulWidget {
  final String farmerId;

  const FarmerDetailsScreen({Key? key, required this.farmerId})
      : super(key: key);

  @override
  State<FarmerDetailsScreen> createState() => _FarmerDetailsScreenState();
}

class _FarmerDetailsScreenState extends State<FarmerDetailsScreen> {
  // Created once so rebuilds never re-subscribe.
  late final Stream<DocumentSnapshot> _farmerStream = FirebaseFirestore.instance
      .collection(AppConstants.farmersCollection)
      .doc(widget.farmerId)
      .snapshots();

  late final Stream<QuerySnapshot> _advancesStream = FirebaseFirestore.instance
      .collection(AppConstants.advancesCollection)
      .where('farmerId', isEqualTo: widget.farmerId)
      .snapshots();

  static const _wideBreakpoint = 900.0;

  double _num(dynamic v) => (v is num) ? v.toDouble() : 0.0;

  String _date(DateTime? d) => d == null
      ? 'N/A'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Farmer Details',
            style: TextStyle(
                color: DashPalette.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Edit farmer',
            icon: const Icon(Icons.edit_outlined, color: DashPalette.ink),
            onPressed: () {
              // TODO: Edit farmer
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _farmerStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _centerMsg(Icons.error_outline_rounded,
                'Could not load farmer', '${snapshot.error}',
                color: DashPalette.red);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(DashPalette.green)),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _centerMsg(Icons.person_off_outlined, 'Farmer not found',
                'This farmer may have been removed.');
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = (data['name'] ?? 'Unknown').toString();
          final phone = (data['phone'] ?? '').toString();
          final notes = (data['notes'] ?? '').toString();
          final branch = (data['branch_name'] ?? '').toString();
          final totalAdvances = _num(data['totalAdvances']);
          final isActive = data['isActive'] ?? true;
          final location = [
            data['village'],
            data['parish'],
            data['subcounty'],
            data['district'],
          ]
              .map((e) => (e ?? '').toString())
              .where((e) => e.isNotEmpty && e != 'N/A')
              .join(', ');

          final profile = _profileCard(
            name: name,
            phone: phone,
            location: location,
            notes: notes,
            branch: branch,
            isActive: isActive,
          );

          final right = StreamBuilder<QuerySnapshot>(
            stream: _advancesStream,
            builder: (context, advSnap) {
              final docs = [...(advSnap.data?.docs ?? [])];
              DateTime? dateOf(QueryDocumentSnapshot d) {
                final m = d.data() as Map<String, dynamic>;
                final ts = (m['advanceDate'] ?? m['createdAt']);
                return ts is Timestamp ? ts.toDate() : null;
              }

              docs.sort((a, b) => (dateOf(b) ?? DateTime(2000))
                  .compareTo(dateOf(a) ?? DateTime(2000)));

              double outstanding = 0;
              int recovered = 0;
              for (final d in docs) {
                final m = d.data() as Map<String, dynamic>;
                final status = (m['status'] ?? 'active').toString();
                if (status == 'fully_recovered') {
                  recovered++;
                } else if (status != 'cancelled') {
                  outstanding += _num(m['remainingAmount']);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryCard(name, totalAdvances, outstanding, recovered,
                      docs.length),
                  const SizedBox(height: 18),
                  LayoutBuilder(builder: (context, rc) {
                    final history = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('Advance history', docs.length),
                        const SizedBox(height: 10),
                        if (!advSnap.hasData)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                        DashPalette.green))),
                          )
                        else if (docs.isEmpty)
                          _emptyBox(Icons.account_balance_wallet_outlined,
                              'No advances given yet')
                        else
                          for (final d in docs) _advanceTile(d, dateOf(d)),
                      ],
                    );
                    final transactions = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('Recent transactions', null),
                        const SizedBox(height: 10),
                        _emptyBox(
                            Icons.receipt_long_outlined, 'No transactions yet'),
                      ],
                    );

                    if (rc.maxWidth >= 820) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: history),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: transactions),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        history,
                        const SizedBox(height: 18),
                        transactions,
                      ],
                    );
                  }),
                ],
              );
            },
          );

          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= _wideBreakpoint;
            final pad = c.maxWidth < 560 ? 14.0 : 24.0;
            // Profile column grows a little with the window (340 - 440px).
            final profileW = (c.maxWidth * 0.27).clamp(340.0, 440.0);
            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: profileW, child: profile),
                        const SizedBox(width: 20),
                        Expanded(child: right),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profile,
                        const SizedBox(height: 16),
                        right,
                      ],
                    ),
            );
          });
        },
      ),
    );
  }

  // ───────────────────────── Profile ─────────────────────────

  BoxDecoration get _cardDeco => BoxDecoration(
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
      );

  Widget _profileCard({
    required String name,
    required String phone,
    required String location,
    required String notes,
    required String branch,
    required bool isActive,
  }) {
    final hasPhone = phone.isNotEmpty && phone != 'N/A';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco,
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? DashPalette.greenSoft : const Color(0xFFEEF1EF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Text(initial,
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: isActive
                        ? DashPalette.greenDark
                        : DashPalette.muted)),
          ),
          const SizedBox(height: 14),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.ink)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(isActive ? 'Active' : 'Inactive',
                  isActive ? DashPalette.green : DashPalette.muted,
                  dot: true),
              if (branch.isNotEmpty)
                _pill(branch, DashPalette.greenDark,
                    icon: Icons.store_mall_directory_outlined),
            ],
          ),
          if (hasPhone) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _contactBtn(
                        Icons.call_rounded,
                        'Call',
                        DashPalette.blue,
                        () => SmsService.makeCall(
                            phoneNumber: phone, context: context))),
                const SizedBox(width: 8),
                Expanded(
                    child: _contactBtn(
                        Icons.sms_rounded,
                        'SMS',
                        DashPalette.greenDark,
                        () => SmsService.sendSMS(
                            phoneNumber: phone, context: context))),
                const SizedBox(width: 8),
                Expanded(
                    child: _contactBtn(
                        Icons.chat_rounded,
                        'WhatsApp',
                        const Color(0xFF1FA855),
                        () => SmsService.openWhatsApp(
                            phoneNumber: phone, context: context))),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: DashPalette.border),
          _infoRow(Icons.phone_outlined, 'Phone', hasPhone ? phone : '—'),
          const Divider(height: 1, color: DashPalette.border),
          _infoRow(Icons.place_outlined, 'Location',
              location.isEmpty ? '—' : location),
          if (notes.isNotEmpty) ...[
            const Divider(height: 1, color: DashPalette.border),
            _infoRow(Icons.sticky_note_2_outlined, 'Notes', notes),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, {bool dot = false, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
          if (icon != null) Icon(icon, size: 14, color: color),
          if (dot || icon != null) const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Widget _contactBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DashPalette.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: DashPalette.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: DashPalette.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Summary ─────────────────────────

  Widget _summaryCard(String name, double total, double outstanding,
      int recovered, int count) {
    Widget mini(String label, String value, Color valueColor) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.7))),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: valueColor)),
                ),
              ],
            ),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DashPalette.ink, DashPalette.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
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
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total advances',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.75))),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(CurrencyFormatter.formatUGX(total),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddAdvanceScreen(
                          farmerId: widget.farmerId, farmerName: name),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: DashPalette.greenDark,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              mini('Outstanding', CurrencyFormatter.formatUGX(outstanding),
                  outstanding > 0
                      ? const Color(0xFFFFB4B4)
                      : Colors.white),
              const SizedBox(width: 10),
              mini('Advances given', '$count', Colors.white),
              const SizedBox(width: 10),
              mini('Recovered', '$recovered', const Color(0xFFB7F0CC)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── History ─────────────────────────

  Widget _sectionHeader(String title, int? count) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink)),
        if (count != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: DashPalette.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.greenDark)),
          ),
        ],
      ],
    );
  }

  Widget _advanceTile(QueryDocumentSnapshot doc, DateTime? date) {
    final m = doc.data() as Map<String, dynamic>;
    final amount = _num(m['amount']);
    final remaining = _num(m['remainingAmount']);
    final status = (m['status'] ?? 'active').toString();
    final note = (m['notes'] ?? '').toString();
    final recovered = status == 'fully_recovered';
    final cancelled = status == 'cancelled';

    final Color tone = recovered
        ? DashPalette.green
        : cancelled
            ? DashPalette.muted
            : DashPalette.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                recovered
                    ? Icons.check_circle_outline_rounded
                    : cancelled
                        ? Icons.block_rounded
                        : Icons.account_balance_wallet_outlined,
                color: tone,
                size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CurrencyFormatter.formatUGX(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.ink)),
                const SizedBox(height: 2),
                Text(_date(date),
                    style: const TextStyle(
                        fontSize: 12.5, color: DashPalette.muted)),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: DashPalette.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (recovered || cancelled)
            _pill(recovered ? 'Recovered' : 'Cancelled', tone)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.formatUGX(remaining),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.red)),
                const SizedBox(height: 2),
                const Text('Remaining',
                    style:
                        TextStyle(fontSize: 11.5, color: DashPalette.muted)),
              ],
            ),
        ],
      ),
    );
  }

  // ───────────────────────── Shared bits ─────────────────────────

  Widget _emptyBox(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashPalette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: DashPalette.muted.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(text,
              style:
                  const TextStyle(fontSize: 14, color: DashPalette.muted)),
        ],
      ),
    );
  }

  Widget _centerMsg(IconData icon, String title, String sub,
      {Color color = DashPalette.green}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: DashPalette.muted)),
          ],
        ),
      ),
    );
  }
}