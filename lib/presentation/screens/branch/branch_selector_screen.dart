import 'package:flutter/material.dart';
import '../../../data/models/branch.dart';
import '../../../domain/services/branch_context.dart';
import '../../../domain/services/branch_service.dart';
import '../../../core/theme/app_theme.dart';

/// Screen for selecting active branch
class BranchSelectorScreen extends StatefulWidget {
  final bool isFirstTime;
  
  const BranchSelectorScreen({
    Key? key,
    this.isFirstTime = false,
  }) : super(key: key);

  @override
  State<BranchSelectorScreen> createState() => _BranchSelectorScreenState();
}

class _BranchSelectorScreenState extends State<BranchSelectorScreen> {
  final BranchService _branchService = BranchService();
  final BranchContext _branchContext = BranchContext.instance;
  
  List<Branch> _branches = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadBranches();
  }
  
  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final branches = await _branchService.getActiveBranches();
      setState(() {
        _branches = branches;
        _isLoading = false;
      });
      
      if (branches.isEmpty) {
        setState(() {
          _errorMessage = 'No active branches found. Please contact administrator.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading branches: $e';
      });
    }
  }
  
  Future<void> _selectBranch(Branch branch) async {
    try {
      await _branchContext.selectBranch(branch);
      
      if (!mounted) return;
      
      // Navigate to home
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting branch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Branch'),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isFirstTime,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1000 : double.infinity,
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? _buildError()
                  : _buildBranchList(isDesktop),
        ),
      ),
    );
  }
  
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBranches,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBranchList(bool isDesktop) {
    final crossAxisCount = isDesktop ? 3 : 1;
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGreen,
                AppTheme.primaryGreen.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.store,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isFirstTime 
                    ? 'Welcome! Select Your Branch'
                    : 'Switch Branch',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_branches.length} branch${_branches.length == 1 ? '' : 'es'} available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isDesktop
              ? GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final branch = _branches[index];
                    final isSelected = _branchContext.currentBranch?.id == branch.id;
                    return _buildBranchCard(branch, isSelected, isDesktop: true);
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final branch = _branches[index];
                    final isSelected = _branchContext.currentBranch?.id == branch.id;
                    return _buildBranchCard(branch, isSelected, isDesktop: false);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildBranchCard(Branch branch, bool isSelected, {required bool isDesktop}) {
    return Card(
      margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      child: InkWell(
        onTap: () => _selectBranch(branch),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppTheme.primaryGreen, width: 2)
                : null,
          ),
          child: isDesktop
              ? _buildDesktopCardContent(branch, isSelected)
              : _buildMobileCardContent(branch, isSelected),
        ),
      ),
    );
  }
  
  Widget _buildDesktopCardContent(Branch branch, bool isSelected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: branch.isHeadOffice
                ? AppTheme.primaryGreen.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            branch.isHeadOffice ? Icons.business : Icons.store,
            size: 40,
            color: branch.isHeadOffice
                ? AppTheme.primaryGreen
                : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          branch.branchName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Code: ${branch.branchCode}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        if (branch.location != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  branch.location!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const Spacer(),
        if (branch.isHeadOffice)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'HEAD OFFICE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        if (isSelected) ...[
          const SizedBox(height: 12),
          const Icon(
            Icons.check_circle,
            color: AppTheme.primaryGreen,
            size: 32,
          ),
        ],
      ],
    );
  }
  
  Widget _buildMobileCardContent(Branch branch, bool isSelected) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: branch.isHeadOffice
                ? AppTheme.primaryGreen.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            branch.isHeadOffice ? Icons.business : Icons.store,
            size: 32,
            color: branch.isHeadOffice
                ? AppTheme.primaryGreen
                : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      branch.branchName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (branch.isHeadOffice)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'HQ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Code: ${branch.branchCode}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (branch.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        branch.location!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (isSelected)
          const Icon(
            Icons.check_circle,
            color: AppTheme.primaryGreen,
            size: 28,
          )
        else
          Icon(
            Icons.arrow_forward_ios,
            size: 20,
            color: Colors.grey[400],
          ),
      ],
    );
  }
  
  Widget _buildOldBranchList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryGreen,
                AppTheme.primaryGreen.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.store,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isFirstTime 
                    ? 'Welcome! Select Your Branch'
                    : 'Switch Branch',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_branches.length} branch${_branches.length == 1 ? '' : 'es'} available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _branches.length,
            itemBuilder: (context, index) {
              final branch = _branches[index];
              final isSelected = _branchContext.currentBranch?.id == branch.id;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isSelected ? 4 : 2,
                child: InkWell(
                  onTap: () => _selectBranch(branch),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryGreen, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: branch.isHeadOffice
                                ? AppTheme.primaryGreen.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            branch.isHeadOffice
                                ? Icons.business
                                : Icons.store,
                            size: 32,
                            color: branch.isHeadOffice
                                ? AppTheme.primaryGreen
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      branch.branchName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (branch.isHeadOffice)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'HQ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Code: ${branch.branchCode}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (branch.location != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        branch.location!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryGreen,
                            size: 28,
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
