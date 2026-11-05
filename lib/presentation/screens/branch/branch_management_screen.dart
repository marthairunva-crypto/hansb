import 'package:flutter/material.dart';
import '../../../data/models/branch.dart';
import '../../../domain/services/branch_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;
import 'branch_form_screen.dart';
import 'branch_stats_screen.dart';

/// Branch management (admin only) - responsive, matches the dashboard theme.
class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({Key? key}) : super(key: key);

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

enum _StatusFilter { all, active, inactive }

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final BranchService _branchService = BranchService();

  List<Branch> _branches = [];
  bool _isLoading = true;
  String _searchQuery = '';
  _StatusFilter _filter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _branchService.getAllBranches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Error loading branches: $e', color: DashPalette.red);
    }
  }

  List<Branch> get _filteredBranches {
    final query = _searchQuery.trim().toLowerCase();
    return _branches.where((b) {
      if (_filter == _StatusFilter.active && !b.isActive) return false;
      if (_filter == _StatusFilter.inactive && b.isActive) return false;
      if (query.isEmpty) return true;
      return b.branchName.toLowerCase().contains(query) ||
          b.branchCode.toLowerCase().contains(query) ||
          (b.location?.toLowerCase().contains(query) ?? false);
    }).toList();
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
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _fmt(num v, {int decimals = 0}) {
    final s = v.toStringAsFixed(decimals);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _openForm({Branch? branch}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
          child: BranchFormScreen(branch: branch),
        ),
      ),
    );
    if (result == true) _loadBranches();
  }

  Future<void> _deleteBranch(Branch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete branch',
          style: TextStyle(fontWeight: FontWeight.w800, color: DashPalette.ink),
        ),
        content: Text(
          'Are you sure you want to delete "${branch.branchName}"?\n\n'
          'The branch will be marked inactive if it has associated records.',
          style: const TextStyle(color: DashPalette.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: DashPalette.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _branchService.deleteBranch(branch.id!);
      _toast('Branch deleted successfully');
      _loadBranches();
    } catch (e) {
      _toast('Error deleting branch: $e', color: DashPalette.red);
    }
  }

  Future<void> _viewBranchStats(Branch branch) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchStatsScreen(branch: branch),
      ),
    );
  }

  Widget _statTile(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DashPalette.muted,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: DashPalette.ink,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final pad = c.maxWidth < 560 ? 16.0 : 24.0;
        final columns = c.maxWidth >= 1300 ? 3 : (c.maxWidth >= 760 ? 2 : 1);
        final list = _filteredBranches;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(wide),
                  const SizedBox(height: 20),
                  _summaryRow(c.maxWidth < 560),
                  const SizedBox(height: 20),
                  _toolbar(wide),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(DashPalette.green),
                      ),
                    )
                  : list.isEmpty
                      ? _emptyState()
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 232,
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, i) => _branchCard(list[i]),
                        ),
            ),
          ],
        );
      }),
    );
  }

  // ───────────────────────── Header / summary / toolbar ─────────────────────────

  Widget _header(bool wide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Branches',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DashPalette.ink,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Manage your head office, branches and their managers',
          style: TextStyle(fontSize: 13.5, color: DashPalette.muted),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _loadBranches,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: DashPalette.ink,
            side: const BorderSide(color: DashPalette.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add branch'),
          style: FilledButton.styleFrom(
            backgroundColor: DashPalette.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Expanded(child: title), actions],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 14), actions],
    );
  }

  Widget _summaryRow(bool compact) {
    final total = _branches.length;
    final active = _branches.where((b) => b.isActive).length;
    final inactive = total - active;

    final cards = [
      _summaryCard(Icons.store_mall_directory_rounded, DashPalette.greenDark,
          'Total branches', total, compact),
      _summaryCard(Icons.check_circle_rounded, DashPalette.green, 'Active',
          active, compact),
      _summaryCard(Icons.pause_circle_rounded, DashPalette.amber, 'Inactive',
          inactive, compact),
    ];

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 10 : 20),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _summaryCard(
      IconData icon, Color color, String label, int value, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18, vertical: compact ? 12 : 16),
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
      child: Row(
        children: [
          if (!compact) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DashPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(bool wide) {
    final search = TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(fontSize: 14.5, color: DashPalette.ink),
      decoration: InputDecoration(
        hintText: 'Search by name, code or location...',
        hintStyle: const TextStyle(color: DashPalette.muted, fontSize: 14),
        prefixIcon:
            const Icon(Icons.search_rounded, color: DashPalette.muted),
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

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterPill('All', _StatusFilter.all),
        _filterPill('Active', _StatusFilter.active),
        _filterPill('Inactive', _StatusFilter.inactive),
      ],
    );

    if (wide) {
      return Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: search,
            ),
          ),
          const Spacer(),
          filters,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [search, const SizedBox(height: 12), filters],
    );
  }

  Widget _filterPill(String label, _StatusFilter value) {
    final selected = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = value),
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

  // ───────────────────────── Empty state ─────────────────────────

  Widget _emptyState() {
    final searching = _searchQuery.isNotEmpty || _filter != _StatusFilter.all;
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
              child: const Icon(Icons.store_mall_directory_outlined,
                  size: 40, color: DashPalette.green),
            ),
            const SizedBox(height: 18),
            Text(
              searching ? 'No matching branches' : 'No branches yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try a different search or filter.'
                  : 'Create your first branch to get started.',
              style: const TextStyle(fontSize: 14, color: DashPalette.muted),
            ),
            if (!searching) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add branch'),
                style: FilledButton.styleFrom(
                  backgroundColor: DashPalette.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Branch card ─────────────────────────

  Widget _branchCard(Branch branch) {
    final accent = branch.isActive ? DashPalette.green : DashPalette.muted;

    final details = <Widget>[];
    void addLine(IconData icon, String? text) {
      if (text == null || text.trim().isEmpty) return;
      if (details.length >= 3) return;
      details.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: DashPalette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: DashPalette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    addLine(Icons.location_on_outlined, branch.location);
    addLine(Icons.person_outline_rounded, branch.managerName);
    addLine(Icons.phone_outlined, branch.phone);
    if (details.length < 3) addLine(Icons.mail_outline_rounded, branch.email);

    return Container(
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
          child: InkWell(
            onTap: () => _openForm(branch: branch),
            hoverColor: DashPalette.greenSoft.withOpacity(0.35),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          branch.isHeadOffice
                              ? Icons.business_rounded
                              : Icons.storefront_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              branch.branchName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: DashPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              branch.branchCode,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: DashPalette.muted,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _statusPill(branch.isActive),
                          if (branch.isHeadOffice) ...[
                            const SizedBox(height: 6),
                            _hqBadge(),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...details,
                  const Spacer(),
                  const Divider(height: 1, color: DashPalette.border),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _cardAction(Icons.analytics_outlined, 'Stats',
                          DashPalette.blue, () => _viewBranchStats(branch)),
                      const SizedBox(width: 4),
                      _cardAction(Icons.edit_outlined, 'Edit',
                          DashPalette.greenDark, () => _openForm(branch: branch)),
                      const Spacer(),
                      if (!branch.isHeadOffice)
                        _cardAction(Icons.delete_outline_rounded, 'Delete',
                            DashPalette.red, () => _deleteBranch(branch)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(bool active) {
    final color = active ? DashPalette.greenDark : DashPalette.red;
    final bg = active ? DashPalette.greenSoft : DashPalette.red.withOpacity(0.1);
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

  Widget _hqBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DashPalette.greenDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'HEAD OFFICE',
        style: TextStyle(
          fontSize: 9.5,
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _cardAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}