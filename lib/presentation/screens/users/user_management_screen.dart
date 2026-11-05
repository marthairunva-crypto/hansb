import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// User Management - create and manage system users.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserRow {
  final String id;
  final Map<String, dynamic> data;
  final String name;
  final String contact;
  final String role;
  final String branchName;
  final bool isActive;

  const _UserRow({
    required this.id,
    required this.data,
    required this.name,
    required this.contact,
    required this.role,
    required this.branchName,
    required this.isActive,
  });
}

class _RoleStyle {
  final String label;
  final Color color;
  const _RoleStyle(this.label, this.color);
}

const Color _purple = Color(0xFF8E44AD);

_RoleStyle _roleStyle(String role) {
  switch (role) {
    case 'superAdmin':
      return const _RoleStyle('Super Admin', _purple);
    case 'branchManager':
      return const _RoleStyle('Branch Manager', DashPalette.blue);
    default:
      return const _RoleStyle('Branch Worker', DashPalette.amber);
  }
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _roleFilters = <String, String>{
    'all': 'All',
    'superAdmin': 'Super Admins',
    'branchManager': 'Managers',
    'branchWorker': 'Workers',
  };

  // Desktop table flex: user, role, branch, status, actions
  static const _flex = [34, 16, 20, 14, 12];

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';

  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('hansb_users')
        .orderBy('display_name')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────── Actions ─────────────────────────

  void _toast(String message, {Color color = DashPalette.greenDark}) {
    if (!mounted) return;
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

  Future<void> _openForm({String? userId, Map<String, dynamic>? userData}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740),
          child: UserFormDialog(userId: userId, userData: userData),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('hansb_users')
          .doc(userId)
          .update({
        'isActive': !currentStatus,
        'is_active': !currentStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
      _toast('User ${!currentStatus ? 'activated' : 'deactivated'} successfully');
    } catch (e) {
      _toast('Error: $e', color: DashPalette.red);
    }
  }

  // ───────────────────────── Data ─────────────────────────

  List<_UserRow> _parse(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return _UserRow(
        id: doc.id,
        data: d,
        name: (d['display_name'] ?? d['name'] ?? 'Unknown').toString(),
        contact: (d['phone'] ?? d['email'] ?? '').toString(),
        role: (d['role'] ?? 'branchWorker').toString(),
        branchName: (d['branch_name'] ?? 'No branch').toString(),
        isActive: (d['is_active'] ?? d['isActive'] ?? true) == true,
      );
    }).toList();
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
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
      );

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 560;
        final wide = c.maxWidth >= 900;
        final pad = compact ? 16.0 : 24.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(wide),
                  const SizedBox(height: 18),
                  _toolbar(wide),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _stateView(Icons.error_outline_rounded,
                        'Something went wrong', '${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(DashPalette.green),
                      ),
                    );
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return _stateView(Icons.people_outline_rounded,
                        'No users yet',
                        'Click "Add user" to create your first user.');
                  }

                  final all = _parse(snapshot.data!.docs);
                  final q = _searchQuery.trim().toLowerCase();
                  final users = all.where((u) {
                    if (_roleFilter != 'all' && u.role != _roleFilter) {
                      return false;
                    }
                    if (q.isEmpty) return true;
                    return u.name.toLowerCase().contains(q) ||
                        u.contact.toLowerCase().contains(q);
                  }).toList();

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
                        sliver: SliverToBoxAdapter(
                          child: _summary(all, wide, compact),
                        ),
                      ),
                      if (users.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _stateView(Icons.search_off_rounded,
                              'No users found', 'Try a different search or filter.'),
                        )
                      else ...[
                        if (wide)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
                            sliver: SliverToBoxAdapter(child: _tableHeader()),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, pad + 56),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: wide
                                    ? _tableRow(users[i])
                                    : _mobileCard(users[i]),
                              ),
                              childCount: users.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ───────────────────────── Header / toolbar ─────────────────────────

  Widget _header(bool wide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Users',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DashPalette.ink,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Manage system users and assign them to branches',
          style: TextStyle(fontSize: 13.5, color: DashPalette.muted),
        ),
      ],
    );

    final add = FilledButton.icon(
      onPressed: () => _openForm(),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
      label: const Text('Add user'),
      style: FilledButton.styleFrom(
        backgroundColor: DashPalette.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (wide) {
      return Row(children: [Expanded(child: title), add]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 14), add],
    );
  }

  Widget _toolbar(bool wide) {
    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(fontSize: 14.5, color: DashPalette.ink),
      decoration: InputDecoration(
        hintText: 'Search by name or phone...',
        hintStyle: const TextStyle(color: DashPalette.muted, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: DashPalette.muted),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: DashPalette.muted),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashPalette.green, width: 1.6),
        ),
      ),
    );

    final pills = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _roleFilters.entries) _pill(e.key, e.value),
      ],
    );

    if (wide) {
      return Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: search,
            ),
          ),
          const Spacer(),
          pills,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [search, const SizedBox(height: 12), pills],
    );
  }

  Widget _pill(String key, String label) {
    final selected = _roleFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _roleFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DashPalette.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DashPalette.green : DashPalette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? DashPalette.greenDark : DashPalette.muted,
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Summary ─────────────────────────

  Widget _summary(List<_UserRow> all, bool wide, bool compact) {
    final active = all.where((u) => u.isActive).length;
    final admins = all.where((u) => u.role == 'superAdmin').length;

    final cards = [
      _statCard(Icons.groups_rounded, DashPalette.blue, 'Total users',
          '${all.length}', compact),
      _statCard(Icons.check_circle_rounded, DashPalette.green, 'Active',
          '$active', compact),
      _statCard(Icons.pause_circle_rounded, DashPalette.amber, 'Inactive',
          '${all.length - active}', compact),
      _statCard(Icons.shield_rounded, _purple, 'Super admins', '$admins',
          compact),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    final gap = compact ? 12.0 : 20.0;
    return Column(
      children: [
        Row(children: [
          Expanded(child: cards[0]),
          SizedBox(width: gap),
          Expanded(child: cards[1]),
        ]),
        SizedBox(height: gap),
        Row(children: [
          Expanded(child: cards[2]),
          SizedBox(width: gap),
          Expanded(child: cards[3]),
        ]),
      ],
    );
  }

  Widget _statCard(IconData icon, Color color, String label, String value,
      bool compact) {
    final iconBox = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 23, color: color),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: DashPalette.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DashPalette.ink,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _cardDecoration(),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [iconBox, const SizedBox(height: 12), text],
            )
          : Row(
              children: [
                iconBox,
                const SizedBox(width: 14),
                Expanded(child: text),
              ],
            ),
    );
  }

  // ───────────────────────── Table (desktop) ─────────────────────────

  Widget _tableHeader() {
    const titles = ['USER', 'ROLE', 'BRANCH', 'STATUS', ''];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (var i = 0; i < titles.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(
                titles[i],
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: DashPalette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(_UserRow u) {
    final initial =
        u.name.trim().isEmpty ? '?' : u.name.trim()[0].toUpperCase();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: u.isActive ? DashPalette.greenSoft : const Color(0xFFEDEFEE),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: u.isActive ? DashPalette.greenDark : DashPalette.muted,
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final s = _roleStyle(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: s.color,
        ),
      ),
    );
  }

  Widget _statusPill(bool active) {
    final color = active ? DashPalette.greenDark : DashPalette.red;
    final bg =
        active ? DashPalette.greenSoft : DashPalette.red.withOpacity(0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _tableRow(_UserRow u) {
    final role = _roleStyle(u.role);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: _flex[0],
            child: Row(
              children: [
                _avatar(u),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color:
                              u.isActive ? DashPalette.ink : DashPalette.muted,
                        ),
                      ),
                      if (u.contact.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          u.contact,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: DashPalette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _flex[1],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _roleBadge(u.role),
            ),
          ),
          Expanded(
            flex: _flex[2],
            child: Row(
              children: [
                if (role.label != 'Super Admin') ...[
                  const Icon(Icons.storefront_outlined,
                      size: 16, color: DashPalette.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      u.branchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: DashPalette.ink,
                      ),
                    ),
                  ),
                ] else
                  const Text(
                    'All branches',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: DashPalette.muted,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: _flex[3],
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusPill(u.isActive),
            ),
          ),
          Expanded(
            flex: _flex[4],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconAction(Icons.edit_outlined, 'Edit user',
                    DashPalette.greenDark,
                    () => _openForm(userId: u.id, userData: u.data)),
                const SizedBox(width: 4),
                _iconAction(
                  u.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                  u.isActive ? 'Deactivate' : 'Activate',
                  u.isActive ? DashPalette.red : DashPalette.green,
                  () => _toggleUserStatus(u.id, u.isActive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Mobile card ─────────────────────────

  Widget _mobileCard(_UserRow u) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(u),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: u.isActive ? DashPalette.ink : DashPalette.muted,
                      ),
                    ),
                    if (u.contact.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        u.contact,
                        style: const TextStyle(
                          fontSize: 12,
                          color: DashPalette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _statusPill(u.isActive),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _roleBadge(u.role),
              if (u.role != 'superAdmin')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_outlined,
                        size: 15, color: DashPalette.muted),
                    const SizedBox(width: 5),
                    Text(
                      u.branchName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: DashPalette.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 24, color: DashPalette.border),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openForm(userId: u.id, userData: u.data),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: DashPalette.greenDark,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _toggleUserStatus(u.id, u.isActive),
                icon: Icon(
                  u.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(u.isActive ? 'Deactivate' : 'Activate'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      u.isActive ? DashPalette.red : DashPalette.green,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stateView(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: DashPalette.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: DashPalette.green),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: DashPalette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Create / edit user dialog
// ═════════════════════════════════════════════════════════════════

class UserFormDialog extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic>? userData;

  const UserFormDialog({Key? key, this.userId, this.userData})
      : super(key: key);

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  String _selectedRole = 'branchWorker';
  String? _selectedBranchId;
  String? _selectedBranchName;
  bool _isLoading = false;
  bool _obscurePin = true;

  late final Stream<QuerySnapshot> _branchStream;

  bool get isEditing => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _branchStream = FirebaseFirestore.instance
        .collection('branches')
        .where('status', isEqualTo: 'ACTIVE')
        .snapshots();

    final d = widget.userData;
    if (d != null) {
      _nameController.text = (d['display_name'] ?? d['name'] ?? '').toString();
      _phoneController.text = (d['phone'] ?? d['email'] ?? '').toString();
      _selectedRole = (d['role'] ?? 'branchWorker').toString();
      _selectedBranchId = d['branch_id'];
      _selectedBranchName = d['branch_name'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    void toast(String m, Color c) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    if (_selectedRole != 'superAdmin' && _selectedBranchId == null) {
      toast('Please select a branch for this user', DashPalette.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final users = FirebaseFirestore.instance.collection('hansb_users');

      if (isEditing) {
        await users.doc(widget.userId).update({
          'name': _nameController.text.trim(),
          'display_name': _nameController.text.trim(),
          'role': _selectedRole,
          'branch_id': _selectedRole == 'superAdmin' ? null : _selectedBranchId,
          'branch_name':
              _selectedRole == 'superAdmin' ? null : _selectedBranchName,
          'updated_at': FieldValue.serverTimestamp(),
        });
        navigator.pop(true);
        toast('User updated successfully', DashPalette.greenDark);
      } else {
        final phone = _phoneController.text.trim();
        final pin = _pinController.text.trim();

        // Don't allow two users with the same phone number
        final existing = await users.where('phone', isEqualTo: phone).limit(1).get();
        if (existing.docs.isNotEmpty) {
          if (mounted) setState(() => _isLoading = false);
          toast('Phone number already registered', DashPalette.red);
          return;
        }

        await users.doc().set({
          'phone': phone,
          'pin': pin,
          'name': _nameController.text.trim(),
          'display_name': _nameController.text.trim(),
          'role': _selectedRole,
          'branch_id': _selectedRole == 'superAdmin' ? null : _selectedBranchId,
          'branch_name':
              _selectedRole == 'superAdmin' ? null : _selectedBranchName,
          'isActive': true,
          'is_active': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        navigator.pop(true);
        toast('User created successfully', DashPalette.greenDark);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      toast('Error: $e', DashPalette.red);
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 520;
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
                    _sectionTitle('Account'),
                    _twoCols(wide, [
                      _labeled(
                        'Full name',
                        required: true,
                        child: TextFormField(
                          controller: _nameController,
                          style: _inputStyle,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoration(
                            icon: Icons.person_outline_rounded,
                            hint: 'e.g. Jane Nakato',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),
                      ),
                      _labeled(
                        'Phone number',
                        required: true,
                        child: TextFormField(
                          controller: _phoneController,
                          style: _inputStyle,
                          readOnly: isEditing,
                          keyboardType: TextInputType.phone,
                          decoration: _decoration(
                            icon: Icons.phone_outlined,
                            hint: 'e.g. 0700123456',
                            locked: isEditing,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            if (v.trim().length < 10) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ]),
                    if (!isEditing) ...[
                      const SizedBox(height: 16),
                      _labeled(
                        'PIN',
                        required: true,
                        child: TextFormField(
                          controller: _pinController,
                          style: _inputStyle,
                          obscureText: _obscurePin,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: _decoration(
                            icon: Icons.lock_outline_rounded,
                            hint: '4 to 6 digits',
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: DashPalette.muted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'PIN is required';
                            if (v.length < 4) return 'Minimum 4 digits';
                            return null;
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    _sectionTitle('Role'),
                    _roleTile('superAdmin', Icons.shield_rounded, 'Super Admin',
                        'Access to all branches', _purple),
                    const SizedBox(height: 10),
                    _roleTile('branchManager', Icons.manage_accounts_rounded,
                        'Branch Manager', 'Assigned to one branch',
                        DashPalette.blue),
                    const SizedBox(height: 10),
                    _roleTile('branchWorker', Icons.badge_outlined,
                        'Branch Worker', 'Assigned to one branch',
                        DashPalette.amber),
                    if (_selectedRole != 'superAdmin') ...[
                      const SizedBox(height: 26),
                      _sectionTitle('Branch'),
                      _branchPicker(),
                      const SizedBox(height: 8),
                      const Text(
                        'This user will only see and manage data for this branch.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: DashPalette.muted,
                        ),
                      ),
                    ],
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
              isEditing ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
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
                  isEditing ? 'Edit user' : 'Add new user',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEditing
                      ? 'Update this user\'s details and access'
                      : 'They will sign in with their phone number and PIN',
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
              onPressed: _isLoading ? null : _saveUser,
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
                  : Text(isEditing ? 'Update user' : 'Create user'),
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
      prefixIcon: Icon(icon, size: 20, color: DashPalette.muted),
      suffixIcon: suffix,
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

  Widget _roleTile(String value, IconData icon, String title, String subtitle,
      Color color) {
    final selected = _selectedRole == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedRole = value;
          if (value == 'superAdmin') {
            _selectedBranchId = null;
            _selectedBranchName = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : DashPalette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: DashPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: DashPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 22)
            else
              const Icon(Icons.radio_button_unchecked_rounded,
                  color: DashPalette.border, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _branchPicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: _branchStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(DashPalette.green),
                ),
              ),
            ),
          );
        }

        final branches = snapshot.data!.docs;
        if (branches.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DashPalette.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DashPalette.amber.withOpacity(0.3)),
            ),
            child: const Text(
              'There are no active branches yet. Create a branch first.',
              style: TextStyle(fontSize: 13, color: DashPalette.ink),
            ),
          );
        }

        final ids = branches.map((d) => d.id).toSet();
        final value = ids.contains(_selectedBranchId) ? _selectedBranchId : null;

        return DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          decoration: _decoration(
            icon: Icons.storefront_outlined,
            hint: 'Select a branch',
          ),
          items: branches.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(
                (data['branch_name'] ?? 'Unknown').toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (v) {
            final selectedDoc = branches.firstWhere((d) => d.id == v);
            final data = selectedDoc.data() as Map<String, dynamic>;
            setState(() {
              _selectedBranchId = v;
              _selectedBranchName = data['branch_name'];
            });
          },
          validator: (v) => v == null ? 'Please select a branch' : null,
        );
      },
    );
  }
}