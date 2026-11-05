import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/sms_service.dart';

/// Messaging Screen - Send SMS/WhatsApp to farmers/customers
class MessagingScreen extends StatefulWidget {
  const MessagingScreen({Key? key}) : super(key: key);

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedFarmers = {};
  bool _selectAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(List<DocumentSnapshot> farmers) {
    setState(() {
      if (_selectAll) {
        _selectedFarmers.clear();
      } else {
        _selectedFarmers.addAll(farmers.map((doc) => doc.id));
      }
      _selectAll = !_selectAll;
    });
  }

  void _showMessageDialog() {
    if (_selectedFarmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one farmer'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send Message to ${_selectedFarmers.length} ${_selectedFarmers.length == 1 ? "farmer" : "farmers"}',
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _sendToSelected('sms');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
            ),
            icon: const Icon(Icons.message, size: 18),
            label: const Text('SMS'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _sendToSelected('whatsapp');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToSelected(String method) async {
    final message = _messageController.text;
    
    try {
      final farmersSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.farmersCollection)
          .where(FieldPath.documentId, whereIn: _selectedFarmers.toList())
          .get();

      for (var doc in farmersSnapshot.docs) {
        final data = doc.data();
        final phone = data['phone'] ?? '';
        
        if (phone.isNotEmpty) {
          if (method == 'sms') {
            await SmsService.sendSMS(
              phoneNumber: phone,
              message: message,
              context: context,
            );
          } else {
            await SmsService.openWhatsApp(
              phoneNumber: phone,
              message: message,
              context: context,
            );
          }
          // Add small delay between messages
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Messages sent to ${_selectedFarmers.length} ${_selectedFarmers.length == 1 ? "farmer" : "farmers"}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear selections
        setState(() {
          _selectedFarmers.clear();
          _selectAll = false;
          _messageController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBrown,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBrown,
        elevation: 0,
        title: const Text(
          'Message Farmers',
          style: TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          if (_selectedFarmers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedFarmers.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textDark),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle: TextStyle(color: AppTheme.textDark.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.accentOrange),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Farmers List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.farmersCollection)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: AppTheme.textLight),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active farmers found',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 16),
                    ),
                  );
                }

                // Filter farmers (both by search and isActive status)
                final farmers = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // Filter out inactive farmers
                  final isActive = data['isActive'] ?? true;
                  if (!isActive) return false;
                  
                  // Search filter
                  if (_searchQuery.isEmpty) return true;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (farmers.isEmpty) {
                  return Center(
                    child: Text(
                      'No farmers found for "$_searchQuery"',
                      style: const TextStyle(color: AppTheme.textLight, fontSize: 16),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Select All
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selectAll,
                            onChanged: (value) => _toggleSelectAll(farmers),
                            activeColor: AppTheme.accentOrange,
                          ),
                          const Text(
                            'Select All',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Farmers List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: farmers.length,
                        itemBuilder: (context, index) {
                          final doc = farmers[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final farmerId = doc.id;
                          final isSelected = _selectedFarmers.contains(farmerId);

                          return _buildFarmerCard(
                            farmerId: farmerId,
                            name: data['name'] ?? 'Unknown',
                            phone: data['phone'] ?? 'N/A',
                            village: data['village'] ?? 'N/A',
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedFarmers.remove(farmerId);
                                } else {
                                  _selectedFarmers.add(farmerId);
                                }
                                _selectAll = _selectedFarmers.length == farmers.length;
                              });
                            },
                            onCall: () {
                              SmsService.makeCall(
                                phoneNumber: data['phone'] ?? '',
                                context: context,
                              );
                            },
                            onSMS: () {
                              SmsService.sendSMS(
                                phoneNumber: data['phone'] ?? '',
                                context: context,
                              );
                            },
                            onWhatsApp: () {
                              SmsService.openWhatsApp(
                                phoneNumber: data['phone'] ?? '',
                                context: context,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedFarmers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showMessageDialog,
              backgroundColor: AppTheme.accentOrange,
              icon: const Icon(Icons.send),
              label: const Text('Send Message'),
            )
          : null,
    );
  }

  Widget _buildFarmerCard({
    required String farmerId,
    required String name,
    required String phone,
    required String village,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onCall,
    required VoidCallback onSMS,
    required VoidCallback onWhatsApp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppTheme.accentOrange, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Checkbox
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => onTap(),
                      activeColor: AppTheme.accentOrange,
                    ),
                    const SizedBox(width: 8),
                    
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.accentOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 14,
                                color: AppTheme.textDark.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  color: AppTheme.textDark.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppTheme.textDark.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  village,
                                  style: TextStyle(
                                    color: AppTheme.textDark.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Action Buttons
                if (phone != 'N/A') ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.phone,
                        label: 'Call',
                        color: Colors.blue,
                        onPressed: onCall,
                      ),
                      _buildActionButton(
                        icon: Icons.message,
                        label: 'SMS',
                        color: AppTheme.accentOrange,
                        onPressed: onSMS,
                      ),
                      _buildActionButton(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        color: Colors.green,
                        onPressed: onWhatsApp,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
