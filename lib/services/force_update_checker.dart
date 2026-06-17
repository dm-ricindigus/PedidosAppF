import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pedidosapp/data/repositories/app_config_repository.dart';
import 'package:pedidosapp/widgets/force_update_screen.dart';

/// Resultado de comparar la versión instalada con la política en Firestore.
typedef ForceUpdateEvaluation = ({
  ForceUpdatePolicy policy,
  Uri? storeUri,
  String currentVersion,
});

/// Chequeo compartido entre splash y revalidación al volver a la app.
class ForceUpdateChecker {
  ForceUpdateChecker({AppConfigRepository? appConfigRepository})
      : _appConfigRepository = appConfigRepository ?? AppConfigRepository();

  final AppConfigRepository _appConfigRepository;

  bool shouldSkip(PackageInfo info) {
    return kDebugMode || kIsWeb || info.packageName.endsWith('.dev');
  }

  Future<ForceUpdateEvaluation?> evaluate({PackageInfo? packageInfo}) async {
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    if (shouldSkip(info)) return null;

    final policy = await _appConfigRepository.fetchForceUpdatePolicy(
      defaultTargetPlatform,
    );
    if (!policy.requiresUpdate(info.version)) return null;

    return (
      policy: policy,
      storeUri: buildStoreUri(defaultTargetPlatform, policy),
      currentVersion: info.version,
    );
  }
}
