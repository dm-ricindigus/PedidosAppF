import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Solo inicializa Firebase (p. ej. isolate de FCM en segundo plano).
Future<void> ensureFirebaseInitialized(FirebaseOptions options) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    } else {
      Firebase.app();
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

/// Firebase + Crashlytics: errores de Flutter y errores async no capturados.
Future<void> initializeFirebaseApp(FirebaseOptions options) async {
  await ensureFirebaseInitialized(options);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
