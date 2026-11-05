import 'package:flutter/material.dart';
import '../../domain/services/branch_context.dart';
import '../../core/theme/app_theme.dart';
import '../screens/branch/branch_selector_screen.dart';

/// Widget to display current branch and allow switching
class BranchIndicator extends StatelessWidget {
  final bool showSwitchButton;
  final bool compact;
  
  const BranchIndicator({
    Key? key,
    this.showSwitchButton = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BranchContext.instance,
      builder: (context, _) {
        final branch = BranchContext.instance.currentBranch;
        
        if (branch == null) {
          return const SizedBox.shrink();
        }
        
        if (compact) {
          return _buildCompactView(context, branch);
        }
        
        return _buildFullView(context, branch);
      },
    );
  }
  
  Widget _buildCompactView(BuildContext context, branch) {
    return InkWell(
      onTap: showSwitchButton 
          ? () => _showBranchSelector(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              branch.isHeadOffice ? Icons.business : Icons.store,
              size: 16,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 6),
            Text(
              branch.branchCode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
            if (showSwitchButton) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.swap_horiz,
                size: 16,
                color: AppTheme.primaryGreen.withOpacity(0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFullView(BuildContext context, branch) {
    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                branch.isHeadOffice ? Icons.business : Icons.store,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.branchName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    branch.location ?? 'No location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showSwitchButton)
              TextButton.icon(
                onPressed: () => _showBranchSelector(context),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Switch'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showBranchSelector(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BranchSelectorScreen(),
      ),
    );
  }
}
