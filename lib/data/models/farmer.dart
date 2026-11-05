/// Farmer entity - represents a coffee farmer registered with HANS. B Trading Company
class Farmer {
  final int? id;
  final String farmerCode;
  final String fullName;
  final String? phone;
  final String? alternativePhone;
  final String? village;
  final String? parish;
  final String? subCounty;
  final String? district;
  final int? branchId;
  final int? farmerGroupId;
  final int? collectionCenterId;
  final double? farmSize;
  final String? coffeeType;
  final DateTime registrationDate;
  final String status; // ACTIVE, INACTIVE, SUSPENDED
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Farmer({
    this.id,
    required this.farmerCode,
    required this.fullName,
    this.phone,
    this.alternativePhone,
    this.village,
    this.parish,
    this.subCounty,
    this.district,
    this.branchId,
    this.farmerGroupId,
    this.collectionCenterId,
    this.farmSize,
    this.coffeeType,
    required this.registrationDate,
    this.status = 'ACTIVE',
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmer_code': farmerCode,
      'full_name': fullName,
      'phone': phone,
      'alternative_phone': alternativePhone,
      'village': village,
      'parish': parish,
      'sub_county': subCounty,
      'district': district,
      'branch_id': branchId,
      'farmer_group_id': farmerGroupId,
      'collection_center_id': collectionCenterId,
      'farm_size': farmSize,
      'coffee_type': coffeeType,
      'registration_date': registrationDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  factory Farmer.fromMap(Map<String, dynamic> map) {
    return Farmer(
      id: map['id'],
      farmerCode: map['farmer_code'],
      fullName: map['full_name'],
      phone: map['phone'],
      alternativePhone: map['alternative_phone'],
      village: map['village'],
      parish: map['parish'],
      subCounty: map['sub_county'],
      district: map['district'],
      branchId: map['branch_id'],
      farmerGroupId: map['farmer_group_id'],
      collectionCenterId: map['collection_center_id'],
      farmSize: map['farm_size']?.toDouble(),
      coffeeType: map['coffee_type'],
      registrationDate: DateTime.parse(map['registration_date']),
      status: map['status'] ?? 'ACTIVE',
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : null,
    );
  }
  
  Farmer copyWith({
    int? id,
    String? farmerCode,
    String? fullName,
    String? phone,
    String? alternativePhone,
    String? village,
    String? parish,
    String? subCounty,
    String? district,
    int? branchId,
    int? farmerGroupId,
    int? collectionCenterId,
    double? farmSize,
    String? coffeeType,
    DateTime? registrationDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Farmer(
      id: id ?? this.id,
      farmerCode: farmerCode ?? this.farmerCode,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      alternativePhone: alternativePhone ?? this.alternativePhone,
      village: village ?? this.village,
      parish: parish ?? this.parish,
      subCounty: subCounty ?? this.subCounty,
      district: district ?? this.district,
      branchId: branchId ?? this.branchId,
      farmerGroupId: farmerGroupId ?? this.farmerGroupId,
      collectionCenterId: collectionCenterId ?? this.collectionCenterId,
      farmSize: farmSize ?? this.farmSize,
      coffeeType: coffeeType ?? this.coffeeType,
      registrationDate: registrationDate ?? this.registrationDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// Get farmer's display location
  String get location {
    final parts = [village, parish, subCounty, district]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Not specified' : parts.join(', ');
  }
  
  /// Check if farmer is active
  bool get isActive => status == 'ACTIVE';
}
