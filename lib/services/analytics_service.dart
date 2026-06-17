import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Firebase Analytics: contexto de dispositivo/app y sesión de usuario.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> configureCollection() async {
    await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);
  }

  /// Eventos automáticos de GA4 + propiedades de versión, plataforma y flavor.
  static Future<void> logAppLaunch() async {
    await _analytics.logAppOpen();

    final info = await PackageInfo.fromPlatform();
    final platform = _platformLabel();
    final flavor = info.packageName.endsWith('.dev') ? 'dev' : 'prod';
    final osVersion = kIsWeb ? 'web' : Platform.operatingSystemVersion;

    await Future.wait([
      _analytics.setUserProperty(name: 'app_version', value: info.version),
      _analytics.setUserProperty(name: 'build_number', value: info.buildNumber),
      _analytics.setUserProperty(name: 'platform', value: platform),
      _analytics.setUserProperty(name: 'package_name', value: info.packageName),
      _analytics.setUserProperty(name: 'flavor', value: flavor),
      _analytics.setUserProperty(name: 'os_version', value: _truncate(osVersion)),
    ]);

    await _analytics.logEvent(
      name: 'app_launch_context',
      parameters: {
        'app_version': info.version,
        'build_number': info.buildNumber,
        'platform': platform,
        'flavor': flavor,
        'package_name': _truncate(info.packageName),
        'os_version': _truncate(osVersion),
      },
    );
  }

  static Future<void> setUserContext({
    required String uid,
    required String role,
  }) async {
    await _analytics.setUserId(id: uid);
    await _analytics.setUserProperty(name: 'user_role', value: role);
    await _analytics.logLogin(loginMethod: 'email');
  }

  static Future<void> clearUserContext() async {
    await _analytics.setUserId(id: null);
    await _analytics.setUserProperty(name: 'user_role', value: null);
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  static String _truncate(String value, {int maxLength = 100}) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
