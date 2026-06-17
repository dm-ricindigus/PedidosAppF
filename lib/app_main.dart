import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pedidosapp/core/app_navigator.dart';
import 'package:pedidosapp/features/admin/home_admin.dart';
import 'package:pedidosapp/features/client/home_client.dart';
import 'package:pedidosapp/data/repositories/app_config_repository.dart';
import 'package:pedidosapp/data/repositories/auth_repository.dart';
import 'package:pedidosapp/features/auth/login.dart';
import 'package:pedidosapp/services/analytics_service.dart';
import 'package:pedidosapp/services/force_update_checker.dart';
import 'package:pedidosapp/widgets/force_update_overlay_host.dart';
import 'package:pedidosapp/widgets/force_update_screen.dart';

class PedidosApp extends StatelessWidget {
  const PedidosApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E008B);

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [AnalyticsService.observer],
      debugShowCheckedModeBanner: false,
      title: 'TSM Clothes',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ForceUpdateOverlayHost(child: child);
      },
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthRepository _authRepository = AuthRepository();
  final ForceUpdateChecker _forceUpdateChecker = ForceUpdateChecker();
  PackageInfo? _packageInfo;
  ({ForceUpdatePolicy policy, Uri? storeUri})? _forceUpdate;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _packageInfo = info;
      _forceUpdate = null;
    });

    final evaluation =
        await _forceUpdateChecker.evaluate(packageInfo: info);
    if (!mounted) return;
    if (evaluation != null) {
      setState(() {
        _forceUpdate = (
          policy: evaluation.policy,
          storeUri: evaluation.storeUri,
        );
      });
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _goToLogin();
  }

  Future<void> _goToLogin() async {
    final user = _authRepository.currentUser;

    if (user != null) {
      try {
        final role = await _authRepository.getRoleForUid(user.uid);
        await AnalyticsService.setUserContext(uid: user.uid, role: role);
        if (!mounted) return;
        if (role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeAdminPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeClientPage()),
          );
        }
        return;
      } catch (_) {
        // Si falla al obtener rol, ir a login
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginPage(title: 'Mi primera aplicacion'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final block = _forceUpdate;
    if (block != null && _packageInfo != null) {
      return ForceUpdateScreen(
        policy: block.policy,
        currentVersion: _packageInfo!.version,
        storeUri: block.storeUri,
        onRecheck: _bootstrap,
      );
    }

    final maxWidth = MediaQuery.sizeOf(context).width - 48;
    final footerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.88),
      height: 1.35,
    );

    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).colorScheme.primary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SizedBox(
                width: maxWidth,
                child: Image.asset(
                  'assets/images/tsm_logo_white.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'The Shoes Magic',
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: _packageInfo == null
                  ? const SizedBox.shrink()
                  : Text(
                      '${_packageInfo!.appName}\n'
                      'v${_packageInfo!.version} (${_packageInfo!.buildNumber})',
                      textAlign: TextAlign.center,
                      style: footerStyle,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
