import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedidosapp/data/repositories/app_config_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla a pantalla completa: solo permite abrir la tienda o reintentar.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.policy,
    required this.currentVersion,
    this.storeUri,
    required this.onRecheck,
  });

  final ForceUpdatePolicy policy;
  final String currentVersion;
  final Uri? storeUri;
  final VoidCallback onRecheck;

  Future<void> _openStore() async {
    final uri = storeUri;
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBody =
        'Tu versión (v$currentVersion) ya no es compatible. '
        'Instala la última actualización para continuar.';
    final body = policy.message?.trim().isNotEmpty == true
        ? policy.message!.trim()
        : defaultBody;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Atrás no vuelve al dashboard; cierra la app (esperado en Android).
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Actualización necesaria',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (storeUri != null)
                  FilledButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Actualizar en la tienda'),
                  )
                else
                  Text(
                    'Falta configurar la URL de App Store en Firestore '
                    '(`iosStoreUrl` o `iosAppStoreId` en appConfig/settings).',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onRecheck,
                  child: const Text('Ya actualicé — comprobar de nuevo'),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Modo debug: puedes usar el menú del sistema para salir.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Construye la [Uri] de la tienda según plataforma y política.
Uri? buildStoreUri(TargetPlatform platform, ForceUpdatePolicy policy) {
  switch (platform) {
    case TargetPlatform.android:
      final id = policy.androidPlayStorePackageId;
      return Uri.parse(
        'https://play.google.com/store/apps/details?id=$id',
      );
    case TargetPlatform.iOS:
      final url = policy.iosStoreUrl;
      if (url != null && url.isNotEmpty) {
        return Uri.parse(url);
      }
      final appId = policy.iosAppStoreId ?? kDefaultIosAppStoreId;
      if (appId.isNotEmpty) {
        return Uri.parse('https://apps.apple.com/app/id$appId');
      }
      return null;
    default:
      return null;
  }
}
