import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pedidosapp/firebase_options.dart';
import 'package:pedidosapp/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PedidosApp());
}

class PedidosApp extends StatelessWidget {
  const PedidosApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E008B); // PMS 2735 (aprox. digital)

    return MaterialApp(
      title: 'Pedidos App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
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
  @override
  void initState() {
    super.initState();
    _goToLogin();
  }

  Future<void> _goToLogin() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginPage(title: 'Mi primera aplicacion'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).colorScheme.primary,
        child: const Center(
          child: Text(
            'Camisetas.com',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
