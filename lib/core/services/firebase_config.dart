import 'package:firebase_core/firebase_core.dart';

/// Firebase Configuration for HANS. B Coffee Management System
class FirebaseConfig {
  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyCswOAVO_R7kMUoCCqzOidbIUKRa4yEb6I",
    authDomain: "my-first-project-e8a6e.firebaseapp.com",
    databaseURL: "https://my-first-project-e8a6e-default-rtdb.firebaseio.com",
    projectId: "my-first-project-e8a6e",
    storageBucket: "my-first-project-e8a6e.firebasestorage.app",
    messagingSenderId: "320732608084",
    appId: "1:320732608084:android:70520e0d8bc4021e66dfc1",
    measurementId: "G-EV5YYG5CBF",
  );
  
  /// Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
  }
}
