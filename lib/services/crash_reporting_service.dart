import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Crashlytics en release/profile: fatales Flutter, async no capturados y nativos (vía SDK).
abstract final class CrashReportingService {
  static Future<void> syncAppContext() async {
    if (kDebugMode) return;

    final info = await PackageInfo.fromPlatform();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCustomKey('app_version', info.version);
    await crashlytics.setCustomKey('build_number', info.buildNumber);
    await crashlytics.setCustomKey('package_name', info.packageName);
    await crashlytics.setCustomKey(
      'flavor',
      info.packageName.endsWith('.dev') ? 'dev' : 'prod',
    );
  }

  static Future<void> flushPendingReports() async {
    if (kDebugMode) return;
    try {
      await FirebaseCrashlytics.instance.sendUnsentReports();
    } catch (_) {}
  }

  /// Errores capturados en try/catch que quieras ver en la consola de Firebase.
  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? reason,
  }) async {
    if (kDebugMode) return;
    final crashlytics = FirebaseCrashlytics.instance;
    if (reason != null) {
      await crashlytics.log(reason);
    }
    await crashlytics.recordError(error, stack, fatal: false);
  }
}
