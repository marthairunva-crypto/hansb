import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBrown,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildContactCard(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Quick Help'),
          _buildHelpCard([
            _buildHelpItem(
              'How to add a farmer?',
              'Go to Farmers tab, tap the + button, fill in farmer details and save.',
              Icons.person_add,
            ),
            const Divider(height: 1),
            _buildHelpItem(
              'How to record a purchase?',
              'Go to Purchases tab, tap +, select farmer, enter weights and quality deductions.',
              Icons.shopping_cart,
            ),
            const Divider(height: 1),
            _buildHelpItem(
              'How to give advances?',
              'Go to Farmers, select a farmer, tap "Give Advance" and enter amount.',
              Icons.attach_money,
            ),
            const Divider(height: 1),
            _buildHelpItem(
              'How to view reports?',
              'Navigate to Reports tab to see business overview, purchases, and inventory.',
              Icons.analytics,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Common Issues'),
          _buildHelpCard([
            _buildExpandableItem(
              'Receipt not printing',
              'Make sure your device is connected to a printer. Check printer settings and try again.',
              Icons.print_disabled,
            ),
            const Divider(height: 1),
            _buildExpandableItem(
              'Data not syncing',
              'Check your internet connection. Data syncs automatically with Firebase when online.',
              Icons.sync_problem,
            ),
            const Divider(height: 1),
            _buildExpandableItem(
              'Cannot login',
              'Verify your phone number and PIN. Contact admin to reset your PIN if needed.',
              Icons.lock_open,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('Get in Touch'),
          _buildContactOptions(context),
          const SizedBox(height: 24),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textLight,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentOrange,
            AppTheme.accentOrange.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.support_agent,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Need Help?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Our support team is here to help you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _callSupport(context),
            icon: const Icon(Icons.phone),
            label: Text('Call ${AppConstants.supportPhone}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.accentOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBrown,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderBrown),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentOrange, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: TextStyle(
              color: AppTheme.textLight.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableItem(String title, String description, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.errorRed, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        iconColor: AppTheme.textLight,
        collapsedIconColor: AppTheme.textLight,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
            child: Text(
              description,
              style: TextStyle(
                color: AppTheme.textLight.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBrown,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderBrown),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildContactButton(
            Icons.phone,
            'Call',
            () => _callSupport(context),
          ),
          _buildContactButton(
            Icons.email,
            'Email',
            () => _emailSupport(context),
          ),
          _buildContactButton(
            Icons.chat,
            'WhatsApp',
            () => _whatsappSupport(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.accentOrange, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBrown,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderBrown),
      ),
      child: Column(
        children: [
          // Version
          Text(
            'Version 1.0.0',
            style: TextStyle(
              color: AppTheme.textLight.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Copyright
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '© 2026 ${AppConstants.companyName}\nAll Rights Reserved',
              style: const TextStyle(
                color: AppTheme.accentOrange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _callSupport(BuildContext context) {
    Clipboard.setData(ClipboardData(text: AppConstants.supportPhone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone number ${AppConstants.supportPhone} copied to clipboard'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _emailSupport(BuildContext context) {
    Clipboard.setData(ClipboardData(text: AppConstants.supportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email ${AppConstants.supportEmail} copied to clipboard'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _whatsappSupport(BuildContext context) {
    Clipboard.setData(ClipboardData(text: AppConstants.supportPhone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone number ${AppConstants.supportPhone} copied. Open WhatsApp to message us.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }
}
