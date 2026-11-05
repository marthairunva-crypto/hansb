/// Business Settings Model - stores company info shown on receipts
class BusinessSettings {
  final String? id;
  final String companyName;
  final String companyNameShort;
  final String division;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String country;
  final String phone;
  final String? phoneAlt;
  final String? email;
  final String receiptFooterMessage; // Custom footer message
  final String receiptPoweredBy; // "Powered by" text
  final DateTime? updatedAt;

  BusinessSettings({
    this.id,
    required this.companyName,
    required this.companyNameShort,
    required this.division,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    this.country = 'Uganda',
    required this.phone,
    this.phoneAlt,
    this.email,
    this.receiptFooterMessage = 'Thank you!',
    this.receiptPoweredBy = 'Powered by Infinitech',
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'company_name': companyName,
      'company_name_short': companyNameShort,
      'division': division,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'country': country,
      'phone': phone,
      'phone_alt': phoneAlt,
      'email': email,
      'receipt_footer_message': receiptFooterMessage,
      'receipt_powered_by': receiptPoweredBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory BusinessSettings.fromMap(Map<String, dynamic> map, String? id) {
    return BusinessSettings(
      id: id,
      companyName: map['company_name'] ?? 'HANS. B TRADING COMPANY LIMITED',
      companyNameShort: map['company_name_short'] ?? 'HANS. B TRADING CO.',
      division: map['division'] ?? 'COFFEE FACTORY',
      addressLine1: map['address_line_1'] ?? 'Nyakyera-Omukatoogo',
      addressLine2: map['address_line_2'] ?? '',
      city: map['city'] ?? 'Ntungamo',
      country: map['country'] ?? 'Uganda',
      phone: map['phone'] ?? '0392945082',
      phoneAlt: map['phone_alt'],
      email: map['email'],
      receiptFooterMessage: map['receipt_footer_message'] ?? 'Thank you!',
      receiptPoweredBy: map['receipt_powered_by'] ?? 'Powered by Infinitech',
      updatedAt: map['updated_at'] != null && map['updated_at'] is String
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  /// Get default settings
  factory BusinessSettings.defaults() {
    return BusinessSettings(
      companyName: 'HANS. B TRADING COMPANY LIMITED',
      companyNameShort: 'HANS. B TRADING CO.',
      division: 'COFFEE FACTORY',
      addressLine1: 'Nyakyera-Omukatoogo',
      addressLine2: '',
      city: 'Ntungamo',
      country: 'Uganda',
      phone: '0392945082',
      phoneAlt: '0706256453',
      email: 'hansbtrading@gmail.com',
      receiptFooterMessage: 'Thank you!',
      receiptPoweredBy: 'Powered by Infinitech',
    );
  }

  BusinessSettings copyWith({
    String? id,
    String? companyName,
    String? companyNameShort,
    String? division,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? country,
    String? phone,
    String? phoneAlt,
    String? email,
    String? receiptFooterMessage,
    String? receiptPoweredBy,
    DateTime? updatedAt,
  }) {
    return BusinessSettings(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      companyNameShort: companyNameShort ?? this.companyNameShort,
      division: division ?? this.division,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      phoneAlt: phoneAlt ?? this.phoneAlt,
      email: email ?? this.email,
      receiptFooterMessage: receiptFooterMessage ?? this.receiptFooterMessage,
      receiptPoweredBy: receiptPoweredBy ?? this.receiptPoweredBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get full address as string
  String get fullAddress {
    final parts = [
      addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      city,
      country,
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(', ');
  }
}
