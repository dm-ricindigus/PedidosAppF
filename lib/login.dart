import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/firebase_options.dart';
import 'package:pedidosapp/home_client.dart';
import 'package:pedidosapp/home_admin.dart';
import 'package:pedidosapp/register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      ),
      home: const LoginPage(title: 'Mi primera aplicacion'),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Usar la base de datos "default" (sin especificar databaseId)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  String? _emailErrorText;
  String? _passwordErrorText;

  Future<void> _hideKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hideKeyboard();
    });
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? emailError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = 'Por favor ingresa tu correo electrónico';
    } else if (!email.contains('@')) {
      emailError = 'Ingresa un correo electrónico válido';
    }

    if (password.trim().isEmpty) {
      passwordError = 'Por favor ingresa tu contraseña';
    }

    if (emailError != null || passwordError != null) {
      setState(() {
        _emailErrorText = emailError;
        _passwordErrorText = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailErrorText = null;
      _passwordErrorText = null;
    });

    try {
      // Autenticar usuario con Firebase
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Obtener el token del usuario autenticado
      User? user = userCredential.user;
      if (user != null) {
        String? idToken = await user.getIdToken();
        developer.log('✅ Login exitoso', name: 'FirebaseAuth');
        developer.log('🔑 Token obtenido: $idToken', name: 'FirebaseAuth');

        // Obtener el rol del usuario desde Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        String role = 'client'; // Rol por defecto
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          role = userData['role'] ?? 'client';
        }

        developer.log('👤 Rol del usuario: $role', name: 'FirebaseAuth');

        if (mounted) {
          // Navegar según el rol del usuario
          if (role == 'admin') {
            developer.log('➡️ Navegando a HomeAdminPage', name: 'FirebaseAuth');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeAdminPage()),
            );
          } else if (role == 'client') {
            developer.log(
              '➡️ Navegando a HomeClientPage',
              name: 'FirebaseAuth',
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeClientPage()),
            );
          } else {
            // Rol desconocido, por defecto va a cliente
            developer.log(
              '⚠️ Rol desconocido: $role, navegando a HomeClientPage',
              name: 'FirebaseAuth',
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeClientPage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al iniciar sesión';

      if (e.code == 'user-not-found') {
        errorMessage = 'No existe una cuenta con este correo electrónico';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Contraseña incorrecta';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El correo electrónico no es válido';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Esta cuenta ha sido deshabilitada';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Demasiados intentos fallidos. Intenta más tarde';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage =
            'La autenticación por email/contraseña no está habilitada';
      } else {
        errorMessage = 'Error: ${e.code}. ${e.message ?? ""}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    'Camisetas.com',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      onChanged: (_) {
                        if (_emailErrorText != null) {
                          setState(() {
                            _emailErrorText = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        hintText: 'ejemplo@correo.com',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email),
                        errorText: _emailErrorText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      onChanged: (_) {
                        if (_passwordErrorText != null) {
                          setState(() {
                            _passwordErrorText = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        hintText: 'Ingresa tu contraseña',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        errorText: _passwordErrorText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            final primary = Theme.of(context).colorScheme.primary;
                            if (states.contains(WidgetState.disabled)) {
                              return primary.withValues(alpha: 0.7);
                            }
                            return primary;
                          }),
                          foregroundColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Ingresar',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () async {
                        await _hideKeyboard();
                        if (!mounted) {
                          return;
                        }
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecoverPasswordPage(
                              initialEmail: _emailController.text.trim(),
                            ),
                          ),
                        );

                        if (!mounted) {
                          return;
                        }
                        await _hideKeyboard();
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        minimumSize: WidgetStateProperty.all(Size.zero),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                      child: Text(
                        'Recuperar contraseña',
                        style: TextStyle(
                          decorationColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('No tienes usuario?'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        await _hideKeyboard();
                        if (!mounted) {
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        minimumSize: WidgetStateProperty.all(Size.zero),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                      ),
                      child: Text(
                        'Registrate',
                        style: TextStyle(
                          decorationColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class RecoverPasswordPage extends StatefulWidget {
  const RecoverPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var emailSent = false;
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());

      if (!mounted) {
        return;
      }
      emailSent = true;
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo enviar el correo de recuperación';

      if (e.code == 'invalid-email') {
        message = 'El correo electrónico no es válido';
      } else if (e.code == 'user-not-found') {
        message = 'No existe una cuenta con este correo electrónico';
      } else if (e.code == 'too-many-requests') {
        message = 'Demasiados intentos. Inténtalo más tarde';
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }

    if (!emailSent || !mounted) {
      return;
    }

    FocusScope.of(context).unfocus();
    final shouldReturnToLogin = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return PopScope(
          canPop: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_read_rounded,
                  color: colorScheme.primary,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  'Correo enviado',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Te enviamos un enlace para cambiar tu contraseña. Revisa bandeja de entrada, spam y promociones.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(sheetContext).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (shouldReturnToLogin == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Transform.translate(
                    offset: const Offset(-24, 0),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Volver',
                    ),
                  ),
                ),
                Icon(
                  Icons.lock_reset,
                  size: 56,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Olvidaste tu contraseña?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isSending,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa tu correo electrónico';
                    }
                    if (!value.contains('@')) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_isSending ? 'Enviando...' : 'Enviar enlace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
