import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth_screen.dart'; // Naya folder structure

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("Firebase init error: $e");
  }
  runApp(const HiiApp());
}

class HiiApp extends StatelessWidget {
  const HiiApp({super.key});

  static const String apiKey = 'AIzaSyA1Dg_ospNbgXatGj4xnWq-1njNc5Y0dCY';
  static const String dbUrl = 'https://irsad-b0b2d-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const int currentAppVersion = 6; 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hii',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const AuthCheck(),
    );
  }
}
