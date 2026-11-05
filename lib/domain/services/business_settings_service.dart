import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/business_settings.dart';

/// Service for managing business settings
class BusinessSettingsService {
  static final BusinessSettingsService instance = BusinessSettingsService._();
  BusinessSettingsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'business_settings';
  final String _docId = 'main'; // Single document for business settings

  BusinessSettings? _cachedSettings;

  /// Get business settings
  Future<BusinessSettings> getSettings() async {
    // Return cached if available
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    try {
      final doc = await _firestore.collection(_collection).doc(_docId).get();

      if (doc.exists) {
        _cachedSettings = BusinessSettings.fromMap(doc.data()!, doc.id);
        return _cachedSettings!;
      } else {
        // Create default settings if not exists
        final defaults = BusinessSettings.defaults();
        await updateSettings(defaults);
        _cachedSettings = defaults;
        return defaults;
      }
    } catch (e) {
      print('Error loading business settings: $e');
      // Return defaults if error
      return BusinessSettings.defaults();
    }
  }

  /// Update business settings
  Future<void> updateSettings(BusinessSettings settings) async {
    try {
      final data = settings.toMap();
      data['updated_at'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collection).doc(_docId).set(
            data,
            SetOptions(merge: true),
          );

      _cachedSettings = settings;
    } catch (e) {
      print('Error updating business settings: $e');
      rethrow;
    }
  }

  /// Clear cache (useful after updates)
  void clearCache() {
    _cachedSettings = null;
  }

  /// Get settings stream for real-time updates
  Stream<BusinessSettings> getSettingsStream() {
    return _firestore
        .collection(_collection)
        .doc(_docId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final settings = BusinessSettings.fromMap(snapshot.data()!, snapshot.id);
        _cachedSettings = settings;
        return settings;
      } else {
        return BusinessSettings.defaults();
      }
    });
  }
}
