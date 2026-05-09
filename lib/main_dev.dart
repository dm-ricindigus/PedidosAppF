import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pedidosapp/app_main.dart';
import 'package:pedidosapp/features/client/home_client.dart';
import 'package:pedidosapp/firebase_options_dev.dart';
import 'package:pedidosapp/services/fcm_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandlerDev(RemoteMessage message) async {
  await _initializeDevFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeDevFirebase();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandlerDev);
  FcmService.setupForegroundHandler();
  FcmService.setupNotificationTapHandler((orderCode) {
    if (orderCode != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeClientPage()),
        (route) => false,
      );
    }
  });
  runApp(const PedidosApp());
}

Future<void> _initializeDevFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DevFirebaseOptions.currentPlatform);
    } else {
      Firebase.app();
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}
