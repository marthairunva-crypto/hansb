import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

/// Service to load dynamic company/business information from Firestore
class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  static CompanyService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  CompanyInfo? _cachedInfo;
  DateTime? _lastFetch;
  
  /// Cache duration - 5 minutes
  final Duration _cacheDuration = const Duration(minutes: 5);

  /// Get company information (cached)
  Future<CompanyInfo> getCompanyInfo() async {
    // Return cached if still valid
    if (_cachedInfo != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedInfo!;
    }

    // Fetch from Firestore
    try {
      final snapshot = await _firestore
          .collection('business_settings')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        _cachedInfo = CompanyInfo.fromMap(data);
        _lastFetch = DateTime.now();
        return _cachedInfo!;
      }
    } catch (e) {
      print('Error loading company info: $e');
    }

    // Return defaults from AppConstants if fetch fails
    return CompanyInfo.fromDefaults();
  }

  /// Clear cache (call this after updating business settings)
  void clearCache() {
    _cachedInfo = null;
    _lastFetch = null;
  }

  /// Get company name synchronously (returns cached or default)
  String get companyName => 
      _cachedInfo?.name ?? AppConstants.companyName;

  /// Get company phones synchronously (returns cached or default)
  List<String> get companyPhones => 
      _cachedInfo?.phones ?? [AppConstants.supportPhone, AppConstants.supportPhoneAlt];

  /// Get company email synchronously (returns cached or default)
  String get companyEmail => 
      _cachedInfo?.email ?? AppConstants.supportEmail;

  /// Get company location synchronously (returns cached or default)
  String get companyLocation => 
      _cachedInfo?.location ?? AppConstants.companyLocation;
}

/// Company/Business Information Model
class CompanyInfo {
  final String name;
  final String email;
  final String location;
  final String address;
  final List<String> phones;

  CompanyInfo({
    required this.name,
    required this.email,
    required this.location,
    required this.address,
    required this.phones,
  });

  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name'] ?? AppConstants.companyName,
      email: map['email'] ?? AppConstants.supportEmail,
      location: map['location'] ?? AppConstants.companyLocation,
      address: map['address'] ?? AppConstants.companyLocation,
      phones: (map['phones'] as List?)?.cast<String>() ?? 
          [AppConstants.supportPhone, AppConstants.supportPhoneAlt],
    );
  }

  factory CompanyInfo.fromDefaults() {
    return CompanyInfo(
      name: AppConstants.companyName,
      email: AppConstants.supportEmail,
      location: AppConstants.companyLocation,
      address: AppConstants.companyLocation,
      phones: [AppConstants.supportPhone, AppConstants.supportPhoneAlt],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'location': location,
      'address': address,
      'phones': phones,
    };
  }

  String get firstPhone => phones.isNotEmpty ? phones.first : '';
  String get phonesFormatted => phones.join(' / ');
}
