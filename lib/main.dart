import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pedidosapp/app_main.dart';
import 'package:pedidosapp/firebase_app_bootstrap.dart';
import 'package:pedidosapp/firebase_options_prod.dart';
import 'package:pedidosapp/services/analytics_service.dart';
import 'package:pedidosapp/services/crash_reporting_service.dart';
import 'package:pedidosapp/services/fcm_navigation.dart';
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
  runApp(const PedidosApp());
  unawaited(_initializeDeferredServices());
}

Future<void> _initializeDeferredServices() async {
  try {
    await AnalyticsService.logAppLaunch();
  } catch (e, st) {
    await CrashReportingService.recordNonFatal(e, st, reason: 'analytics');
  }
  try {
    await FcmService.initialize(onNotificationTap: handleFcmNotificationTap);
  } catch (e, st) {
    await CrashReportingService.recordNonFatal(e, st, reason: 'fcm_init');
  }
  try {
    await CrashReportingService.syncAppContext();
    await CrashReportingService.flushPendingReports();
  } catch (e, st) {
    await CrashReportingService.recordNonFatal(e, st, reason: 'crashlytics_sync');
  }
}
