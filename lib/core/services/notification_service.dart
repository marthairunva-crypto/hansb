import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../constants/app_constants.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

/// Notification Service for handling push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  
  NotificationService._internal();

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    try {
      // Request permission for notifications (important for iOS, optional for Android)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
        
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        print('FCM Token: $_fcmToken');
        
        // Save token to Firestore for the current user
        await _saveFCMToken();
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveFCMToken);
        
        // Set up message handlers
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
      } else {
        print('User declined notification permission');
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  /// Save FCM token to Firestore for current user
  Future<void> _saveFCMToken([String? token]) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;
      
      final tokenToSave = token ?? _fcmToken;
      if (tokenToSave == null) return;

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(currentUser.uid)
          .update({
        'fcmToken': tokenToSave,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      
      print('FCM token saved to Firestore');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.notification?.title}');
    // You can show a local notification or update UI here
  }

  /// Handle messages when user taps notification (app in background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.notification?.title}');
    // Navigate to specific screen based on message data
  }

  /// Send notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data();
      final fcmToken = userData?['fcmToken'] as String?;
      
      if (fcmToken == null) {
        print('User has no FCM token');
        return;
      }

      // Store notification in Firestore (for in-app notification history)
      await FirebaseFirestore.instance
          .collection(AppConstants.notificationsCollection)
          .add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('Notification saved to Firestore for user: $userId');
      
      // Note: Actual push sending requires Firebase Cloud Functions or a backend
      // For now, we're just storing in Firestore for in-app notifications
      
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Send notification to all branch users
  Future<void> sendNotificationToBranch({
    required String branchId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all users in the branch
      final usersSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('branchId', isEqualTo: branchId)
          .get();
      
      for (var userDoc in usersSnapshot.docs) {
        await sendNotificationToUser(
          userId: userDoc.id,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      print('Error sending branch notification: $e');
    }
  }

  /// Send notification when purchase is created
  Future<void> notifyPurchaseCreated({
    required String farmerName,
    required double netPayment,
    required String branchId,
  }) async {
    await sendNotificationToBranch(
      branchId: branchId,
      title: 'New Purchase Recorded',
      body: '$farmerName - UGX ${netPayment.toStringAsFixed(0)}',
      data: {
        'type': 'purchase',
        'farmerName': farmerName,
        'amount': netPayment,
      },
    );
  }

  /// Send notification when farmer is added
  Future<void> notifyFarmerAdded({
    required String farmerName,
    required String branchId,
  }) async {
    await sendNotificationToBranch(
      branchId: branchId,
      title: 'New Farmer Added',
      body: '$farmerName registered successfully',
      data: {
        'type': 'farmer',
        'farmerName': farmerName,
      },
    );
  }

  /// Send notification when advance is given
  Future<void> notifyAdvanceGiven({
    required String farmerName,
    required double amount,
    required String branchId,
  }) async {
    await sendNotificationToBranch(
      branchId: branchId,
      title: 'Advance Given',
      body: '$farmerName received UGX ${amount.toStringAsFixed(0)}',
      data: {
        'type': 'advance',
        'farmerName': farmerName,
        'amount': amount,
      },
    );
  }

  /// Get unread notification count for current user
  Stream<int> getUnreadCountStream() {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }
}
