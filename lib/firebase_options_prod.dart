// Firebase producción — pedidos-alkoto-prod
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class ProdFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'ProdFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'ProdFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBuU8zHJGzECBTTZUTLY-sdqxTzH0NgRWE',
    appId: '1:978040200097:android:0f4afb4fa20e31d9f749e0',
    messagingSenderId: '978040200097',
    projectId: 'pedidos-alkoto-prod',
    storageBucket: 'pedidos-alkoto-prod.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCzZcflUrfshAf0eEcV4P0WI2rxkzvZDXE',
    appId: '1:978040200097:ios:06a8260aa31d8962f749e0',
    messagingSenderId: '978040200097',
    projectId: 'pedidos-alkoto-prod',
    storageBucket: 'pedidos-alkoto-prod.firebasestorage.app',
    iosBundleId: 'com.ricindigus.tsm.pedidosapp',
  );

}