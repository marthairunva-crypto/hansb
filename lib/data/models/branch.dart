/// Branch entity - represents different branches of HANS. B Trading Company
class Branch {
  final String? id; // Firestore document ID
  final String branchCode;
  final String branchName;
  final String? location;
  final String? address;
  final String? managerName;
  final String? phone;
  final String? email;
  final String status; // ACTIVE, INACTIVE
  final bool isHeadOffice;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Branch({
    this.id,
    required this.branchCode,
    required this.branchName,
    this.location,
    this.address,
    this.managerName,
    this.phone,
    this.email,
    this.status = 'ACTIVE',
    this.isHeadOffice = false,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'branch_code': branchCode,
      'branch_name': branchName,
      'location': location,
      'address': address,
      'manager_name': managerName,
      'phone': phone,
      'email': email,
      'status': status,
      'is_head_office': isHeadOffice,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      id: map['id'],
      branchCode: map['branch_code'] ?? '',
      branchName: map['branch_name'] ?? '',
      location: map['location'],
      address: map['address'],
      managerName: map['manager_name'],
      phone: map['phone'],
      email: map['email'],
      status: map['status'] ?? 'ACTIVE',
      isHeadOffice: map['is_head_office'] == true || map['is_head_office'] == 1,
      notes: map['notes'],
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null && map['updated_at'] is String
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }
  
  Branch copyWith({
    String? id,
    String? branchCode,
    String? branchName,
    String? location,
    String? address,
    String? managerName,
    String? phone,
    String? email,
    String? status,
    bool? isHeadOffice,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Branch(
      id: id ?? this.id,
      branchCode: branchCode ?? this.branchCode,
      branchName: branchName ?? this.branchName,
      location: location ?? this.location,
      address: address ?? this.address,
      managerName: managerName ?? this.managerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      isHeadOffice: isHeadOffice ?? this.isHeadOffice,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// Check if branch is active
  bool get isActive => status == 'ACTIVE';
  
  /// Get full branch display name
  String get displayName => '$branchCode - $branchName';
  
  /// Get full address with location
  String get fullAddress {
    final parts = [address, location]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Address not specified' : parts.join(', ');
  }
}
