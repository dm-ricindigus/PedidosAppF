import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pedidosapp/app_main.dart';
import 'package:pedidosapp/features/admin/home_admin.dart';
import 'package:pedidosapp/features/client/home_client.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/firebase_app_bootstrap.dart';
import 'package:pedidosapp/firebase_options_prod.dart';
import 'package:pedidosapp/services/fcm_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandlerProd(
  RemoteMessage message,
) async {
  await ensureFirebaseInitialized(ProdFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseApp(ProdFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandlerProd);
  FcmService.setupForegroundHandler();
  FcmService.setupNotificationTapHandler((data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'] as String?;
    if (type == FcmNotificationTypes.newOrderForAdmin ||
        type == FcmNotificationTypes.clientMessageForAdmin) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeAdminPage()),
        (route) => false,
      );
      return;
    }

    final orderCode = data[FirestoreFields.orderCode] as String?;
    if (orderCode != null && orderCode.isNotEmpty) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeClientPage()),
        (route) => false,
      );
    }
  });
  runApp(const PedidosApp());
}
