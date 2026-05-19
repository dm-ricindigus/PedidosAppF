import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pedidosapp/app_main.dart';
import 'package:pedidosapp/features/client/home_client.dart';
import 'package:pedidosapp/firebase_app_bootstrap.dart';
import 'package:pedidosapp/firebase_options_dev.dart';
import 'package:pedidosapp/services/fcm_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandlerDev(RemoteMessage message) async {
  await ensureFirebaseInitialized(DevFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseApp(DevFirebaseOptions.currentPlatform);
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
