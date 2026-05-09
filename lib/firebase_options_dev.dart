// Firebase desarrollo — pedidosapp-5eb2c
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DevFirebaseOptions have not been configured for web.',
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
          'DevFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBO1bu-bBnqzPy-pmdcQJhxeQ2K5Iv_ubY',
    appId: '1:60224711452:android:3084c3fc59262f047b28d9',
    messagingSenderId: '60224711452',
    projectId: 'pedidosapp-5eb2c',
    storageBucket: 'pedidosapp-5eb2c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDU4rNGfl4aQJ9eKvq-TkwWV2j4uBX2UQY',
    appId: '1:60224711452:ios:3053f68031c789537b28d9',
    messagingSenderId: '60224711452',
    projectId: 'pedidosapp-5eb2c',
    storageBucket: 'pedidosapp-5eb2c.firebasestorage.app',
    iosBundleId: 'com.ricindigus.tsm.pedidosapp',
  );

}