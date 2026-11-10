import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationController = TextEditingController();
  
  final List<TextEditingController> _phoneControllers = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _businessDocId;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBusinessData() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _firestore.collection('business_settings').limit(1).get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        _businessDocId = doc.id;
        final data = doc.data();
        
        _nameController.text = data['name'] ?? 'HANSB Trading Co.';
        _emailController.text = data['email'] ?? 'info@hansb.com';
        _addressController.text = data['address'] ?? 'Kampala, Uganda';
        _locationController.text = data['location'] ?? 'Kampala, Uganda';
        
        final phones = (data['phones'] as List?)?.cast<String>() ?? ['0700000000'];
        _phoneControllers.clear();
        for (var phone in phones) {
          final controller = TextEditingController(text: phone);
          _phoneControllers.add(controller);
        }
      } else {
        // Create default document
        final docRef = await _firestore.collection('business_settings').add({
          'name': 'HANSB Trading Co.',
          'email': 'info@hansb.com',
          'address': 'Kampala, Uganda',
          'location': 'Kampala, Uganda',
          'phones': ['0700000000'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _businessDocId = docRef.id;
        _nameController.text = 'HANSB Trading Co.';
        _emailController.text = 'info@hansb.com';
        _addressController.text = 'Kampala, Uganda';
        _locationController.text = 'Kampala, Uganda';
        _phoneControllers.add(TextEditingController(text: '0700000000'));
      }
    } catch (e) {
      _showSnackBar('Error loading data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBusinessData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final phones = _phoneControllers
          .map((c) => c.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      
      if (phones.isEmpty) {
        _showSnackBar('Add at least one phone number', isError: true);
        setState(() => _isSaving = false);
        return;
      }
      
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'location': _locationController.text.trim(),
        'phones': phones,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (_businessDocId != null) {
        await _firestore.collection('business_settings').doc(_businessDocId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await _firestore.collection('business_settings').add(data);
        _businessDocId = docRef.id;
      }
      
      _showSnackBar('Business settings saved successfully');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error saving: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addPhoneField() {
    setState(() {
      _phoneControllers.add(TextEditingController());
    });
  }

  void _removePhoneField(int index) {
    if (_phoneControllers.length > 1) {
      setState(() {
        _phoneControllers[index].dispose();
        _phoneControllers.removeAt(index);
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : DashPalette.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Business Settings'),
        backgroundColor: DashPalette.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: DashPalette.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.business,
                                        color: DashPalette.green,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Company Information',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Update your business details',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                
                                // Business Name
                                const Text(
                                  'Business Name',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter business name',
                                    prefixIcon: const Icon(Icons.store),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Business name is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Email
                                const Text(
                                  'Email Address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'Enter email address',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Location
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Kampala, Uganda',
                                    prefixIcon: const Icon(Icons.location_on_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Location is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Address
                                const Text(
                                  'Physical Address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _addressController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: 'Enter full address',
                                    prefixIcon: const Icon(Icons.home_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Address is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Phone Numbers
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Phone Numbers',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _addPhoneField,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Phone'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: DashPalette.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // Phone Fields
                                ..._phoneControllers.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final controller = entry.value;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: controller,
                                            keyboardType: TextInputType.phone,
                                            decoration: InputDecoration(
                                              hintText: 'e.g., 0700000000',
                                              prefixIcon: const Icon(Icons.phone_outlined),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Phone number required';
                                              }
                                              if (value.trim().length < 10) {
                                                return 'Enter valid phone number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        if (_phoneControllers.length > 1) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () => _removePhoneField(index),
                                            icon: const Icon(Icons.delete_outline),
                                            color: Colors.red,
                                            tooltip: 'Remove',
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Save Button
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveBusinessData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DashPalette.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
