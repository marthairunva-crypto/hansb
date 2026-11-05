import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../farmers/farmers_screen.dart';
import '../farmers/add_farmer_screen.dart';
import '../purchases/purchases_screen.dart';
import '../purchases/add_purchase_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/reports_screen.dart';
import '../users/user_management_screen.dart';
import '../settings/settings_screen.dart';
import '../help/help_support_screen.dart';
import '../branch/branch_management_screen.dart';
import 'dashboard_home_new.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isAdmin; // Whether this is an admin-only item
  const _NavItem(this.icon, this.activeIcon, this.label, {this.isAdmin = false});
}

/// Tells the dashboard whether a sub-screen (e.g. "Add Farmer") is open
/// inside the content area, so the floating button can hide itself.
class _SubRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> subOpen;
  _SubRouteObserver(this.subOpen);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    subOpen.value = previousRoute != null;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final prev = previousRoute;
    subOpen.value = prev != null && !prev.isFirst;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final prev = previousRoute;
    subOpen.value = prev != null && !prev.isFirst;
  }
}

/// Main Dashboard Screen - Coffee Business Management
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Nested navigator (desktop): screens opened from any page appear INSIDE
  // the white content panel, so the sidebar and header stay visible.
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _indexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _subOpen = ValueNotifier<bool>(false);
  late final _SubRouteObserver _observer = _SubRouteObserver(_subOpen);

  static const _nav = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Dashboard'),
    _NavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Farmers'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Purchases'),
    _NavItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports'),
    _NavItem(Icons.store_outlined, Icons.store, 'Branch Management', isAdmin: true),
    _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts, 'User Management', isAdmin: true),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings', isAdmin: true),
    _NavItem(Icons.help_outline_rounded, Icons.help, 'Help & Support', isAdmin: true),
  ];

  @override
  void dispose() {
    _indexNotifier.dispose();
    _subOpen.dispose();
    super.dispose();
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'superAdmin':
        return 'Administrator';
      case 'branchManager':
        return 'Branch Manager';
      case 'worker':
        return 'Worker';
      default:
        return 'User';
    }
  }

  void _select(int i) {
    // Close any open sub-screen (add farmer, etc.) when switching tabs
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() => _selectedIndex = i);
    _indexNotifier.value = i;
  }

  List<Widget> _buildPages() => [
        DashboardHomeNew(onNavigate: _select),
        const FarmersScreen(),
        const PurchasesScreen(),
        const InventoryScreen(),
        const ReportsScreen(),
        const BranchManagementScreen(),
        UserManagementScreen(),
        const SettingsScreen(),
        const HelpSupportScreen(),
      ];

  void _logout() {
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: DashPalette.outer,
        floatingActionButton: _fabSlot(isDesktop: true),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(width: 252, child: _sidebar(inDrawer: false)),
                const SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _desktopHeader(),
                          const Divider(height: 1, color: DashPalette.line),
                          Expanded(child: _contentNavigator()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Phone / tablet: pages are shown directly; forms open full screen.
    final pages = _buildPages();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: DashPalette.ink),
        titleSpacing: 0,
        title: Row(
          children: [
            _logo(32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppConstants.companyNameShort,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DashPalette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _headerIcon(Icons.notifications_none_rounded, () {}),
          const SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DashPalette.line),
        ),
      ),
      drawer: Drawer(
        width: 290,
        backgroundColor: DashPalette.sidebar,
        shape: const RoundedRectangleBorder(),
        child: _sidebar(inDrawer: true),
      ),
      body: pages[_selectedIndex],
      floatingActionButton: _buildFAB(isDesktop: false),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DashPalette.line)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex.clamp(0, 4), // Clamp to main tabs only
          onTap: _select,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: DashPalette.greenDark,
          unselectedItemColor: DashPalette.muted,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
            // Only show first 5 main tabs in bottom nav
            for (var i = 0; i < 5 && i < _nav.length; i++)
              BottomNavigationBarItem(
                icon: Icon(_nav[i].icon),
                activeIcon: Icon(_nav[i].activeIcon),
                label: _nav[i].label,
              ),
          ],
        ),
      ),
    );
  }

  /// The nested navigator that hosts the current page and anything opened from it.
  Widget _contentNavigator() {
    return Navigator(
      key: _contentNav,
      observers: [_observer],
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _indexNotifier,
          builder: (_, i, __) => _buildPages()[i],
        ),
      ),
    );
  }

  /// Desktop FAB slot: hidden while a form is open inside the content area.
  Widget _fabSlot({required bool isDesktop}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _subOpen,
      builder: (_, open, __) =>
          open ? const SizedBox.shrink() : (_buildFAB(isDesktop: isDesktop) ?? const SizedBox.shrink()),
    );
  }

  // ───────────────────────── Desktop header ─────────────────────────

  Widget _desktopHeader() {
    final userName = AuthService.instance.currentUser?.displayName ?? 'User';
    final title = _selectedIndex == 0
        ? '${dashGreeting()}, $userName'
        : _nav[_selectedIndex].label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
          ),
          _headerIcon(Icons.notifications_none_rounded, () {}),
          const SizedBox(width: 10),
          _headerIcon(Icons.bolt_rounded, () {
            // Quick action: go to Purchases
            _select(2);
          }),
          const SizedBox(width: 16),
          Container(width: 1, height: 28, color: DashPalette.line),
          const SizedBox(width: 16),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DashPalette.greenSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: DashPalette.greenDark)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DashPalette.ink)),
              Text(_getRoleDisplayName(AuthService.instance.currentUser?.role?.toString() ?? 'user'),
                  style: const TextStyle(fontSize: 12, color: DashPalette.muted)),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: DashPalette.muted),
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: DashPalette.line),
        ),
        child: Icon(icon, size: 19, color: DashPalette.ink),
      ),
    );
  }

  // ───────────────────────── Sidebar ─────────────────────────

  Widget _sidebar({required bool inDrawer}) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: Column(
        children: [
          // Brand
          Row(
            children: [
              _logo(38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppConstants.companyNameShort,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    size: 18, color: Colors.white.withOpacity(0.75)),
                const SizedBox(width: 8),
                Text('Search...',
                    style: TextStyle(
                        fontSize: 14, color: Colors.white.withOpacity(0.75))),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('General'),
                  for (var i = 0; i < 5; i++) // Dashboard, Farmers, Purchases, Inventory, Reports
                    _navTile(
                      icon: _selectedIndex == i ? _nav[i].activeIcon : _nav[i].icon,
                      label: _nav[i].label,
                      selected: _selectedIndex == i,
                      onTap: () {
                        _select(i);
                        if (inDrawer) Navigator.pop(context);
                      },
                    ),
                  const SizedBox(height: 24),
                  // Only show Admin section for superAdmins
                  if (AuthService.instance.isSuperAdmin) ...[
                    _sectionLabel('Admin'),
                    for (var i = 5; i < _nav.length; i++) // Admin items
                      _navTile(
                        icon: _selectedIndex == i ? _nav[i].activeIcon : _nav[i].icon,
                        label: _nav[i].label,
                        selected: _selectedIndex == i,
                        onTap: () {
                          _select(i);
                          if (inDrawer) Navigator.pop(context);
                        },
                      ),
                  ],
                  // Settings for everyone
                  if (!AuthService.instance.isSuperAdmin) ...[
                    const SizedBox(height: 24),
                    _sectionLabel('Settings'),
                    _navTile(
                      icon: _selectedIndex == 7 ? Icons.settings : Icons.settings_outlined,
                      label: 'Settings',
                      selected: _selectedIndex == 7,
                      onTap: () {
                        _select(7);
                        if (inDrawer) Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Account card (bottom)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DashPalette.green.withOpacity(0.7), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: DashPalette.green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        (AuthService.instance.currentUser?.displayName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthService.instance.currentUser?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            AuthService.instance.currentUser?.branchName ?? 
                                AuthService.instance.currentUser?.role.name ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC3D3C9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _logout,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sign out',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.logout_rounded,
                            size: 16, color: DashPalette.green),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: DashPalette.sidebar,
        borderRadius: inDrawer ? BorderRadius.zero : BorderRadius.circular(20),
      ),
      child: inDrawer ? SafeArea(child: content) : content,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB3C6BA),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: selected ? DashPalette.navActive : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? Colors.white : const Color(0xFFD3E0D8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFFD3E0D8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Shared bits ─────────────────────────

  Widget _logo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: DashPalette.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/logo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.coffee,
            size: size * 0.55,
            color: DashPalette.green,
          ),
        ),
      ),
    );
  }

  /// Opens an add form: inside the content panel on desktop (sidebar stays),
  /// full screen on phones.
  void _openAddScreen(Widget screen, {required bool isDesktop}) {
    final route = MaterialPageRoute(builder: (_) => screen);
    if (isDesktop && _contentNav.currentState != null) {
      _contentNav.currentState!.push(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  Widget? _buildFAB({required bool isDesktop}) {
    Widget fab(Widget screen) => FloatingActionButton(
          onPressed: () => _openAddScreen(screen, isDesktop: isDesktop),
          backgroundColor: DashPalette.ink,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        );

    switch (_selectedIndex) {
      case 1: // Farmers tab
        return fab(const AddFarmerScreen());
      case 2: // Purchases tab
        return fab(const AddPurchaseScreen());
      default:
        return null;
    }
  }
}