import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pedidosapp/core/version_utils.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/firestore_collections.dart';

/// Id de documento en [FirestoreCollections.appConfig].
const String kAppConfigSettingsDocId = 'settings';

/// Paquete de producción en Play Store (flavor `prod` en Android).
const String kDefaultAndroidPlayStorePackageId =
    'com.ricindigus.tsm.pedidosapp.prod';

/// Política leída de Firestore para obligar actualización.
class ForceUpdatePolicy {
  const ForceUpdatePolicy({
    required this.enabled,
    required this.minVersionForPlatform,
    required this.androidPlayStorePackageId,
    this.iosStoreUrl,
    this.iosAppStoreId,
    this.message,
  });

  final bool enabled;
  final String? minVersionForPlatform;
  final String androidPlayStorePackageId;
  final String? iosStoreUrl;
  final String? iosAppStoreId;
  final String? message;

  /// `true` si la versión instalada es estrictamente menor que la mínima.
  bool requiresUpdate(String currentAppVersion) {
    if (!enabled) return false;
    final min = minVersionForPlatform;
    if (min == null || min.isEmpty) return false;
    return VersionUtils.compare(currentAppVersion, min) < 0;
  }
}

class AppConfigRepository {
  AppConfigRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<ForceUpdatePolicy> fetchForceUpdatePolicy(
    TargetPlatform platform,
  ) async {
    try {
      final snap = await _db
          .collection(FirestoreCollections.appConfig)
          .doc(kAppConfigSettingsDocId)
          .get();
      if (!snap.exists) {
        return ForceUpdatePolicy(
          enabled: false,
          minVersionForPlatform: null,
          androidPlayStorePackageId: kDefaultAndroidPlayStorePackageId,
        );
      }

      final data = snap.data() ?? {};
      final enabled = data[FirestoreFields.forceUpdateEnabled];
      final isEnabled = enabled is! bool || enabled;

      final minCommon = _minVersionField(data, FirestoreFields.minVersion);
      final minAndroidOnly =
          _minVersionField(data, FirestoreFields.minVersionAndroid);
      final minIosOnly = _minVersionField(data, FirestoreFields.minVersionIos);

      // `minVersion` es el mínimo global; los campos por plataforma añaden un
      // requisito extra. La versión exigida es la más alta entre ambos (no se
      // ignora `minVersion` solo porque exista `minVersionAndroid`).
      final minAndroid = VersionUtils.strictestMin(minCommon, minAndroidOnly);
      final minIos = VersionUtils.strictestMin(minCommon, minIosOnly);
      final minForPlatform = switch (platform) {
        TargetPlatform.android => minAndroid,
        TargetPlatform.iOS => minIos,
        _ => minCommon,
      };

      return ForceUpdatePolicy(
        enabled: isEnabled,
        minVersionForPlatform: minForPlatform,
        androidPlayStorePackageId: _stringField(
              data,
              FirestoreFields.androidPlayStorePackageId,
            ) ??
            kDefaultAndroidPlayStorePackageId,
        iosStoreUrl: _stringField(data, FirestoreFields.iosStoreUrl),
        iosAppStoreId: _stringField(data, FirestoreFields.iosAppStoreId),
        message: _stringField(data, FirestoreFields.forceUpdateMessage),
      );
    } catch (e, st) {
      debugPrint('AppConfigRepository: no se pudo leer appConfig: $e\n$st');
      return ForceUpdatePolicy(
        enabled: false,
        minVersionForPlatform: null,
        androidPlayStorePackageId: kDefaultAndroidPlayStorePackageId,
      );
    }
  }

  static String? _minVersionField(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is num) return v.toString();
    return null;
  }

  static String? _stringField(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }
}
