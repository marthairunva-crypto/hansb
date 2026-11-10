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
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _NavSection {
  final String title;
  final List<int> indexes;
  const _NavSection(this.title, this.indexes);
}

/// compact  : phones            (< 720)   -> app bar + drawer + bottom nav
/// medium   : tablets / small   (720-1099) -> icon rail + content panel
/// expanded : desktop           (>= 1100) -> full sidebar + content panel
enum _Layout { compact, medium, expanded }

_Layout _layoutFor(double width) {
  if (width >= 1100) return _Layout.expanded;
  if (width >= 720) return _Layout.medium;
  return _Layout.compact;
}

/// Tells the dashboard whether a sub-screen (e.g. "Add Farmer") is open
/// inside the content area, so the floating button can hide itself.
class _SubRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> subOpen;
  _SubRouteObserver(this.subOpen);

  void _update(Route<dynamic>? previousRoute) {
    // Defer so we never notify listeners in the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      subOpen.value = previousRoute != null && !previousRoute.isFirst;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => subOpen.value = previousRoute != null);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);
}

/// Main Dashboard Screen - Coffee Business Management
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Nested navigator (medium/expanded): screens opened from any page appear
  // INSIDE the white content panel, so the sidebar and header stay visible.
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
    _NavItem(Icons.store_outlined, Icons.store, 'Branch Management'),
    _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts, 'User Management'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
    _NavItem(Icons.help_outline_rounded, Icons.help, 'Help & Support'),
  ];

  // Bottom nav on phones: 4 main tabs + "More" (opens the drawer).
  static const int _bottomTabs = 4;

  @override
  void dispose() {
    _indexNotifier.dispose();
    _subOpen.dispose();
    super.dispose();
  }

  // ───────────────────────── Data helpers ─────────────────────────

  String get _userName =>
      AuthService.instance.currentUser?.displayName ?? 'User';

  String get _initial => _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';

  String get _roleLabel {
    final role = AuthService.instance.currentUser?.role.name ?? 'user';
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

  List<_NavSection> get _sections {
    final isSuper = AuthService.instance.isSuperAdmin;
    return [
      const _NavSection('General', [0, 1, 2, 3, 4]),
      if (isSuper) const _NavSection('Admin', [5, 6]),
      const _NavSection('Support', [7, 8]),
    ];
  }

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return DashboardHomeNew(onNavigate: _select);
      case 1:
        return FarmersScreen();
      case 2:
        return const PurchasesScreen();
      case 3:
        return const InventoryScreen();
      case 4:
        return const ReportsScreen();
      case 5:
        return const BranchManagementScreen();
      case 6:
        return UserManagementScreen();
      case 7:
        return const SettingsScreen();
      case 8:
        return const HelpSupportScreen();
      default:
        return DashboardHomeNew(onNavigate: _select);
    }
  }

  void _select(int i) {
    // Close any open sub-screen (add farmer, etc.) when switching tabs
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() => _selectedIndex = i);
    _indexNotifier.value = i;
  }

  void _logout() {
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _layoutFor(constraints.maxWidth);
        return layout == _Layout.compact
            ? _buildCompact()
            : _buildPanel(layout, constraints.maxWidth);
      },
    );
  }

  // ───────────────── Medium + Expanded (sidebar / rail) ─────────────────

  Widget _buildPanel(_Layout layout, double width) {
    final expanded = layout == _Layout.expanded;
    final gap = expanded ? 16.0 : 10.0;
    final sidebarWidth = expanded ? (width >= 1300 ? 252.0 : 224.0) : 76.0;

    return Scaffold(
      backgroundColor: DashPalette.outer,
      floatingActionButton: _fabSlot(),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _sidebar(inDrawer: false, collapsed: !expanded),
              ),
              SizedBox(width: gap),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        _panelHeader(showUserText: expanded || width >= 900),
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

  /// The nested navigator that hosts the current page and anything opened from it.
  Widget _contentNavigator() {
    return Navigator(
      key: _contentNav,
      observers: [_observer],
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _indexNotifier,
          builder: (_, i, __) =>
              KeyedSubtree(key: ValueKey(i), child: _pageFor(i)),
        ),
      ),
    );
  }

  Widget _fabSlot() {
    return ValueListenableBuilder<bool>(
      valueListenable: _subOpen,
      builder: (_, open, __) =>
          open ? const SizedBox.shrink() : (_buildFAB(isPanel: true) ?? const SizedBox.shrink()),
    );
  }

  Widget _panelHeader({required bool showUserText}) {
    final title = _selectedIndex == 0
        ? '${dashGreeting()}, $_userName'
        : _nav[_selectedIndex].label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _headerIcon(Icons.notifications_none_rounded, () {}),
          const SizedBox(width: 8),
          _headerIcon(Icons.bolt_rounded, () => _select(2)), // quick: Purchases
          const SizedBox(width: 14),
          Container(width: 1, height: 28, color: DashPalette.line),
          const SizedBox(width: 14),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 44),
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _avatar(36, DashPalette.greenSoft, DashPalette.greenDark),
                if (showUserText) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: DashPalette.ink)),
                        Text(_roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: DashPalette.muted)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: DashPalette.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Compact (phones) ─────────────────────────

  Widget _buildCompact() {
    final isHome = _selectedIndex == 0;
    return Scaffold(
      key: _scaffoldKey,
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
            if (isHome) ...[
              _logo(32),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                isHome ? AppConstants.companyNameShort : _nav[_selectedIndex].label,
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
        child: _sidebar(inDrawer: true, collapsed: false),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _pageFor(_selectedIndex),
        ),
      ),
      floatingActionButton: _buildFAB(isPanel: false),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DashPalette.line)),
        ),
        child: BottomNavigationBar(
          // Pages beyond the first 4 live under "More".
          currentIndex: _selectedIndex < _bottomTabs ? _selectedIndex : _bottomTabs,
          onTap: (i) {
            if (i == _bottomTabs) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              _select(i);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: DashPalette.greenDark,
          unselectedItemColor: DashPalette.muted,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
            for (var i = 0; i < _bottomTabs; i++)
              BottomNavigationBarItem(
                icon: Icon(_nav[i].icon),
                activeIcon: Icon(_nav[i].activeIcon),
                label: _nav[i].label,
              ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_rounded),
              activeIcon: Icon(Icons.menu_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Sidebar / rail / drawer ─────────────────────────

  Widget _sidebar({required bool inDrawer, required bool collapsed}) {
    void go(int i) {
      _select(i);
      if (inDrawer) Navigator.pop(context);
    }

    final content = Padding(
      padding: collapsed
          ? const EdgeInsets.fromLTRB(10, 16, 10, 12)
          : const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: Column(
        children: [
          // Brand
          if (collapsed)
            Center(child: _logo(40))
          else
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
          SizedBox(height: collapsed ? 18 : 20),

          // Search (full sidebar only)
          if (!collapsed) ...[
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
                  Expanded(
                    child: Text('Search...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, color: Colors.white.withOpacity(0.75))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Navigation (scrolls on short screens)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  for (var s = 0; s < _sections.length; s++) ...[
                    if (s > 0) SizedBox(height: collapsed ? 10 : 20),
                    if (collapsed && s > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                            width: 24,
                            height: 1,
                            color: Colors.white.withOpacity(0.12)),
                      )
                    else if (!collapsed)
                      _sectionLabel(_sections[s].title),
                    for (final i in _sections[s].indexes)
                      _navTile(
                        icon: _selectedIndex == i ? _nav[i].activeIcon : _nav[i].icon,
                        label: _nav[i].label,
                        selected: _selectedIndex == i,
                        collapsed: collapsed,
                        onTap: () => go(i),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          collapsed ? _collapsedAccount() : _accountCard(),
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

  Widget _accountCard() {
    final user = AuthService.instance.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashPalette.green.withOpacity(0.7), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _avatar(30, DashPalette.green, Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user?.branchName ?? user?.role.name ?? 'User',
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
                  Icon(Icons.logout_rounded, size: 16, color: DashPalette.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collapsedAccount() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '$_userName • $_roleLabel',
          child: _avatar(36, DashPalette.green, Colors.white),
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: 'Sign out',
          child: InkWell(
            onTap: _logout,
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(
              width: 44,
              height: 40,
              child: Icon(Icons.logout_rounded, size: 20, color: DashPalette.green),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB3C6BA),
          fontSize: 13,
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
    required bool collapsed,
    bool selected = false,
  }) {
    final fg = selected ? Colors.white : const Color(0xFFD3E0D8);
    final bg = selected ? DashPalette.navActive : Colors.transparent;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: collapsed
            ? Container(
                width: 48,
                height: 46,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 21, color: fg),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: collapsed ? Tooltip(message: label, child: tile) : tile,
    );
  }

  // ───────────────────────── Shared bits ─────────────────────────

  Widget _avatar(double size, Color bg, Color fg) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        _initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
          color: fg,
        ),
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

  /// Opens an add form: inside the content panel on tablet/desktop
  /// (sidebar stays), full screen on phones.
  void _openAddScreen(Widget screen, {required bool isPanel}) {
    final route = MaterialPageRoute(builder: (_) => screen);
    if (isPanel && _contentNav.currentState != null) {
      _contentNav.currentState!.push(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  Widget? _buildFAB({required bool isPanel}) {
    Widget fab(Widget screen) => FloatingActionButton(
          onPressed: () => _openAddScreen(screen, isPanel: isPanel),
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