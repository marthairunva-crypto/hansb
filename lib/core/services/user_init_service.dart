import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';
import '../utils/phone_pin_auth.dart';

/// User Initialization Service
/// Automatically creates default admin account on first launch
class UserInitService {
  static Future<void> initializeDefaultAdmin() async {
    try {
      final defaultPhone = AppConstants.supportPhone;
      const defaultPin = '1234';
      
      // Convert phone + PIN to email + password for Firebase Auth
      final email = PhonePinAuth.emailFor(defaultPhone);
      final password = PhonePinAuth.passwordFor(defaultPin);

      // Check if default admin Firebase Auth account exists
      try {
        // Try to sign in to check if account exists
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Account exists, sign out
        await FirebaseAuth.instance.signOut();
        print('✅ Users collection already initialized');
        return;
      } on FirebaseAuthException catch (e) {
        // Account doesn't exist, create it
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // Create Firebase Auth account
          final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Create Firestore user document
          await FirebaseFirestore.instance
              .collection(AppConstants.usersCollection)
              .doc(userCredential.user!.uid)
              .set({
            'uid': userCredential.user!.uid,
            'email': email,
            'display_name': 'Admin User',
            'phone': defaultPhone,
            'role': 'superAdmin',
            'branch_id': null,
            'branch_name': null,
            'is_active': true,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Sign out
          await FirebaseAuth.instance.signOut();

          print('✅ Default admin account created successfully');
          print('📱 Phone: $defaultPhone');
          print('🔒 PIN: $defaultPin');
        } else {
          throw e;
        }
      }
    } catch (e) {
      print('❌ Error initializing default admin: $e');
    }
  }
}
