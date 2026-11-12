import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/services/company_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {

  static const _wideBreakpoint = 900.0;

  // Developer (Infinitech) contacts
  static const _phone1 = '0778474686';
  static const _phone2 = '0795551296';
  static const _email = 'info@infinitech.co.ug';

  CompanyInfo? _companyInfo;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    final info = await CompanyService.instance.getCompanyInfo();
    if (mounted) {
      setState(() {
        _companyInfo = info;
      });
    }
  }

  static const _quickHelp = <_Help>[
    _Help(
      'How to add a farmer?',
      'Go to the Farmers tab, tap the + button, fill in the farmer details and save.',
      Icons.person_add_alt_1_rounded,
    ),
    _Help(
      'How to record a purchase?',
      'Go to the Purchases tab, tap +, select the farmer, then enter weights and quality deductions.',
      Icons.shopping_cart_outlined,
    ),
    _Help(
      'How to give an advance?',
      'Open Farmers, select a farmer and tap Add on the advances card, then enter the amount.',
      Icons.payments_outlined,
    ),
    _Help(
      'How to view reports?',
      'Open the Reports tab to see the business overview, purchases and inventory.',
      Icons.bar_chart_rounded,
    ),
  ];

  static const _issues = <_Help>[
    _Help(
      'Receipt not printing',
      'Make sure your device is connected to a printer. Check the printer settings and try again.',
      Icons.print_disabled_outlined,
    ),
    _Help(
      'Data not syncing',
      'Check your internet connection. Data syncs automatically with Firebase when you are online.',
      Icons.sync_problem_outlined,
    ),
    _Help(
      'Cannot login',
      'Verify your phone number and PIN. Contact an admin to reset your PIN if needed.',
      Icons.lock_open_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= _wideBreakpoint;
        final pad = c.maxWidth < 560 ? 14.0 : 24.0;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Quick help', Icons.lightbulb_outline_rounded),
            const SizedBox(height: 10),
            _card(
              child: Column(
                children: [
                  for (var i = 0; i < _quickHelp.length; i++) ...[
                    _helpTile(_quickHelp[i]),
                    if (i != _quickHelp.length - 1) _divider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle('Common issues', Icons.build_circle_outlined),
            const SizedBox(height: 10),
            _card(
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: DashPalette.greenSoft,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _issues.length; i++) ...[
                      _issueTile(_issues[i]),
                      if (i != _issues.length - 1) _divider(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Get in touch', Icons.forum_outlined),
            const SizedBox(height: 10),
            _contactOptions(context),
            const SizedBox(height: 22),
            _aboutCard(),
          ],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(context, wide),
              const SizedBox(height: 22),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 22),
                    Expanded(flex: 2, child: right),
                  ],
                )
              else ...[
                left,
                const SizedBox(height: 22),
                right,
              ],
            ],
          ),
        );
      }),
    );
  }

  // ───────────────────────── Pieces ─────────────────────────

  Widget _hero(BuildContext context, bool wide) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Need help?',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 6),
        Text('Our developers at Infinitech are here to help you with anything.',
            style: TextStyle(
                fontSize: 14.5, color: Colors.white.withOpacity(0.78))),
      ],
    );

    final buttons = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: () => _call(context),
          icon: const Icon(Icons.phone_rounded, size: 18),
          label: const Text('Call $_phone1',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: DashPalette.greenDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _whatsapp(context),
          icon: const Icon(Icons.chat_rounded, size: 18),
          label: const Text('WhatsApp',
              style: TextStyle(fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.45)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );

    final icon = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.support_agent_rounded,
          size: 34, color: Colors.white),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 26 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DashPalette.ink, DashPalette.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: wide
          ? Row(
              children: [
                icon,
                const SizedBox(width: 20),
                Expanded(child: text),
                const SizedBox(width: 16),
                buttons,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(height: 14),
                text,
                const SizedBox(height: 16),
                buttons,
              ],
            ),
    );
  }

  Widget _sectionTitle(String t, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: DashPalette.greenSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: DashPalette.greenDark),
        ),
        const SizedBox(width: 10),
        Text(t,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink)),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: ClipRRect(borderRadius: BorderRadius.circular(15), child: child),
    );
  }

  Widget _divider() => const Divider(height: 1, color: DashPalette.border);

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }

  Widget _helpTile(_Help h) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(h.icon, DashPalette.green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DashPalette.ink)),
                const SizedBox(height: 4),
                Text(h.body,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: DashPalette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _issueTile(_Help h) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: DashPalette.greenDark,
      collapsedIconColor: DashPalette.muted,
      leading: _iconBox(h.icon, DashPalette.red),
      title: Text(h.title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: DashPalette.ink)),
      children: [
        Text(h.body,
            style: const TextStyle(
                fontSize: 13.5, height: 1.45, color: DashPalette.muted)),
      ],
    );
  }

  Widget _contactOptions(BuildContext context) {
    return _card(
      child: Column(
        children: [
          _contactRow(Icons.phone_rounded, 'Call developer', _phone1,
              DashPalette.blue, () => _callNumber(context, _phone1)),
          _divider(),
          _contactRow(Icons.phone_rounded, 'Call developer (alt.)', _phone2,
              DashPalette.blue, () => _callNumber(context, _phone2)),
          _divider(),
          _contactRow(Icons.chat_rounded, 'WhatsApp', _phone1,
              const Color(0xFF1FA855), () => _whatsapp(context)),
          _divider(),
          _contactRow(Icons.email_rounded, 'Email', _email,
              DashPalette.greenDark,
              () => _copy(context, _email, 'Email'),
              trailing: Icons.copy_rounded),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value, Color color,
      VoidCallback onTap,
      {IconData trailing = Icons.arrow_forward_ios_rounded}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _iconBox(icon, color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12.5, color: DashPalette.muted)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DashPalette.ink)),
                ],
              ),
            ),
            Icon(trailing, size: 16, color: DashPalette.muted),
          ],
        ),
      ),
    );
  }

  Widget _aboutCard() {
    return _card(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Version 1.0.0',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DashPalette.muted)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: DashPalette.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '© 2026 ${_companyInfo?.name ?? AppConstants.companyName}\nAll Rights Reserved',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: DashPalette.greenDark,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Powered by',
              style: TextStyle(fontSize: 11.5, color: DashPalette.muted)),
          const SizedBox(height: 2),
          const Text('Infinitech Innovations Ltd',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.ink)),
        ],
      ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  void _call(BuildContext context) => _callNumber(context, _phone1);

  void _callNumber(BuildContext context, String number) =>
      SmsService.makeCall(phoneNumber: number, context: context);

  void _whatsapp(BuildContext context) =>
      SmsService.openWhatsApp(phoneNumber: _phone1, context: context);

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: DashPalette.greenDark,
        content: Text('$label $value copied to clipboard'),
      ),
    );
  }
}

class _Help {
  final String title;
  final String body;
  final IconData icon;
  const _Help(this.title, this.body, this.icon);
}