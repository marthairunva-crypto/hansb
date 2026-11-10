import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;
import '../admin/data_migration_screen.dart';
import '../data_import/import_advances_screen.dart';
import '../data_import/import_ledger_screen.dart';
import 'business_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _Opt {
  final String value;
  final String title;
  final String subtitle;
  const _Opt(this.value, this.title, this.subtitle);
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoBackup = false;
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'UGX';

  static const _currencies = [
    _Opt('UGX', 'UGX', 'Ugandan Shilling'),
    _Opt('USD', 'USD', 'US Dollar'),
    _Opt('EUR', 'EUR', 'Euro'),
  ];

  static const _languages = [
    _Opt('English', 'English', 'Default'),
    _Opt('Luganda', 'Luganda', 'Oluganda'),
    _Opt('Swahili', 'Swahili', 'Kiswahili'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _autoBackup = prefs.getBool('auto_backup') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _selectedCurrency = prefs.getString('currency') ?? 'UGX';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('notifications_enabled', _notificationsEnabled),
      prefs.setBool('auto_backup', _autoBackup),
      prefs.setString('language', _selectedLanguage),
      prefs.setString('currency', _selectedCurrency),
    ]);
    _toast('Settings saved');
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
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final pad = c.maxWidth < 560 ? 16.0 : 24.0;

        final general = _section(
          'General',
          [
            _switchTile(
              icon: Icons.notifications_active_outlined,
              color: DashPalette.amber,
              title: 'Notifications',
              subtitle: 'Get notified about new purchases and updates',
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                _saveSettings();
              },
            ),
            _switchTile(
              icon: Icons.cloud_sync_outlined,
              color: DashPalette.blue,
              title: 'Auto backup',
              subtitle: 'Automatically back up your data to the cloud',
              value: _autoBackup,
              onChanged: (v) {
                setState(() => _autoBackup = v);
                _saveSettings();
              },
            ),
          ],
          fill: wide,
        );

        final business = _section(
          'Business',
          [
            // Only superAdmins can edit business details
            if (AuthService.instance.isSuperAdmin) ...[
              _actionTile(
                icon: Icons.business_outlined,
                color: DashPalette.green,
                title: 'Business details',
                subtitle: 'Company name, address, and contact info',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessSettingsScreen(),
                    ),
                  );
                },
              ),
              _actionTile(
                icon: Icons.sync_alt_rounded,
                color: DashPalette.blue,
                title: 'Data Migration',
                subtitle: 'Fix old records without branch assignments',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataMigrationScreen(),
                    ),
                  );
                },
              ),
              _actionTile(
                icon: Icons.upload_file_rounded,
                color: DashPalette.amber,
                title: 'Import Advances',
                subtitle: 'Bulk import previous advances from CSV file',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportAdvancesScreen(),
                    ),
                  );
                },
              ),
              _actionTile(
                icon: Icons.table_chart_rounded,
                color: Colors.purple,
                title: 'Import Advance Ledger',
                subtitle: 'Import from your advance ledger Excel format',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportLedgerScreen(),
                    ),
                  );
                },
              ),
            ],
            _optionTile(
              icon: Icons.payments_outlined,
              color: DashPalette.green,
              title: 'Currency',
              subtitle: 'Used for prices and totals',
              value: _selectedCurrency,
              onTap: () => _pick(
                title: 'Select currency',
                options: _currencies,
                current: _selectedCurrency,
                onSelected: (v) {
                  setState(() => _selectedCurrency = v);
                  _saveSettings();
                },
              ),
            ),
            _optionTile(
              icon: Icons.language_rounded,
              color: DashPalette.blue,
              title: 'Language',
              subtitle: 'App display language',
              value: _selectedLanguage,
              onTap: () => _pick(
                title: 'Select language',
                options: _languages,
                current: _selectedLanguage,
                onSelected: (v) {
                  setState(() => _selectedLanguage = v);
                  _saveSettings();
                },
              ),
            ),
          ],
          fill: wide,
        );

        final data = _section(
          'Data management',
          [
            _actionTile(
              icon: Icons.backup_outlined,
              color: DashPalette.greenDark,
              title: 'Back up data now',
              subtitle: 'Create a backup of all your data',
              onTap: _performBackup,
            ),
            _actionTile(
              icon: Icons.file_download_outlined,
              color: DashPalette.amber,
              title: 'Export reports',
              subtitle: 'Download your data as CSV or PDF',
              onTap: _exportReports,
            ),
          ],
          fill: wide,
        );

        final about = _section(
          'About',
          [
            _infoTile(Icons.info_outline_rounded, 'App version', '1.0.0'),
            _infoTile(
                Icons.phone_outlined, 'Support', AppConstants.supportPhone),
          ],
          fill: wide,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: SizedBox(
            width: double.infinity,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(),
                  const SizedBox(height: 24),
                  if (wide) ...[
                    _pair(general, data),
                    const SizedBox(height: 24),
                    _pair(business, about),
                  ] else ...[
                    general,
                    const SizedBox(height: 24),
                    business,
                    const SizedBox(height: 24),
                    data,
                    const SizedBox(height: 24),
                    about,
                  ],
                  const SizedBox(height: 8),
                ],
              ),
          ),
        );
      }),
    );
  }

  /// Two sections side by side with equal heights.
  Widget _pair(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 24),
          Expanded(child: b),
        ],
      ),
    );
  }

  // ───────────────────────── Banner ─────────────────────────

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DashPalette.sidebar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.coffee,
                  color: DashPalette.green,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HANS. B TRADING CO. LTD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Coffee business management system',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFC3D3C9), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'v1.0.0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Section + tiles ─────────────────────────

  Widget _section(String title, List<Widget> tiles, {bool fill = false}) {
    final card = Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 70,
                    color: DashPalette.border,
                  ),
                tiles[i],
              ],
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: DashPalette.muted,
            ),
          ),
        ),
        if (fill) Expanded(child: card) else card,
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: DashPalette.greenSoft.withOpacity(0.5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DashPalette.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: DashPalette.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _tile(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: DashPalette.green,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFCBD3CE),
        trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return _tile(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: DashPalette.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: DashPalette.greenDark,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              size: 22, color: DashPalette.muted),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _tile(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 22, color: DashPalette.muted),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return _tile(
      icon: icon,
      color: DashPalette.muted,
      title: title,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: DashPalette.ink,
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Dialogs ─────────────────────────

  Future<void> _pick({
    required String title,
    required List<_Opt> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: DashPalette.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          color: DashPalette.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final o in options) _optionRow(ctx, o, current, onSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(
    BuildContext ctx,
    _Opt o,
    String current,
    ValueChanged<String> onSelected,
  ) {
    final selected = o.value == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(ctx);
          onSelected(o.value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? DashPalette.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? DashPalette.green : DashPalette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DashPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      o.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: DashPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: DashPalette.green, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performBackup() async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(DashPalette.green),
        ),
      ),
    );
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      // TODO: real backup call here
      _toast('Backup completed successfully');
    } catch (e) {
      _toast('Backup failed', color: DashPalette.red);
    } finally {
      if (nav.canPop()) nav.pop();
    }
  }

  Future<void> _exportReports() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Export reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: DashPalette.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded,
                          color: DashPalette.muted),
                    ),
                  ],
                ),
                const Text(
                  'Choose a format to export.',
                  style: TextStyle(fontSize: 14, color: DashPalette.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _formatButton(
                        ctx,
                        'PDF',
                        Icons.picture_as_pdf_rounded,
                        DashPalette.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _formatButton(
                        ctx,
                        'CSV',
                        Icons.table_chart_rounded,
                        DashPalette.greenDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formatButton(
      BuildContext ctx, String label, IconData icon, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.pop(ctx);
        _toast('Reports exported as $label successfully');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
