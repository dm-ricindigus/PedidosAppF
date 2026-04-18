import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pedidosapp/data/repositories/auth_repository.dart';
import 'package:pedidosapp/features/admin/home_admin.dart';
import 'package:pedidosapp/features/auth/register.dart';
import 'package:pedidosapp/features/auth/widgets/login_screen_widgets.dart';
import 'package:pedidosapp/features/client/home_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();
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

  Future<void> _showEmailNotVerifiedSheet(
    BuildContext context,
    User user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (ctx) => LoginEmailVerificationSheet(
        onResend: () => _authRepo.sendEmailVerification(user),
      ),
    );
  }

  Future<void> _openRecoverPassword() async {
    final navigator = Navigator.of(context);
    await _hideKeyboard();
    if (!mounted) return;
    await navigator.push<bool>(
      MaterialPageRoute(
        builder: (context) => const RecoverPasswordPage(),
      ),
    );
    if (!mounted) return;
    await _hideKeyboard();
  }

  Future<void> _openRegister() async {
    final navigator = Navigator.of(context);
    await _hideKeyboard();
    if (!mounted) return;
    navigator.push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
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
      UserCredential userCredential =
          await _authRepo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        user = await _authRepo.reloadAuthenticatedUser(user);
        if (user != null && !user.emailVerified) {
          if (mounted) {
            await _showEmailNotVerifiedSheet(context, user);
            await _authRepo.signOut();
          }
          return;
        }

        if (user == null) return;

        String? idToken = await user.getIdToken();
        developer.log('✅ Login exitoso', name: 'FirebaseAuth');
        developer.log('🔑 Token obtenido: $idToken', name: 'FirebaseAuth');

        final String role = await _authRepo.getRoleForUid(user.uid);

        developer.log('👤 Rol del usuario: $role', name: 'FirebaseAuth');

        if (mounted) {
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
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Correo o contraseña incorrectos';
      } else if (e.code == 'network-request-failed') {
        errorMessage =
            'Sin conexión. Comprueba tu red e intenta de nuevo.';
      } else {
        errorMessage =
            'No se pudo iniciar sesión. Intenta de nuevo más tarde.';
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
          const SnackBar(
            content: Text(
              'Ocurrió un error inesperado. Intenta de nuevo.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
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
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  flex: 1,
                  child: Center(child: LoginBrandingTitle()),
                ),
                LoginCredentialsForm(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  isLoading: _isLoading,
                  emailErrorText: _emailErrorText,
                  passwordErrorText: _passwordErrorText,
                  onEmailEdited: () {
                    if (_emailErrorText != null) {
                      setState(() => _emailErrorText = null);
                    }
                  },
                  onPasswordEdited: () {
                    if (_passwordErrorText != null) {
                      setState(() => _passwordErrorText = null);
                    }
                  },
                  onTogglePasswordVisibility: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  onSubmit: _signIn,
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: LoginSecondaryActions(
                      isLoading: _isLoading,
                      onRecoverPassword: _openRecoverPassword,
                      onGoRegister: _openRegister,
                    ),
                  ),
                ),
              ],
            ),
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
  const RecoverPasswordPage({super.key});

  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  final AuthRepository _authRepo = AuthRepository();
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
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
      await _authRepo.sendPasswordResetEmail(_emailController.text.trim());

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
      } else if (e.code == 'network-request-failed') {
        message =
            'Sin conexión. Comprueba tu red e intenta de nuevo.';
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
        _errorMessage =
            'Ocurrió un error inesperado. Intenta de nuevo.';
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
      builder: (_) => const RecoverPasswordEmailSentSheet(),
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RecoverPasswordFormContent(
            formKey: _formKey,
            emailController: _emailController,
            isSending: _isSending,
            errorMessage: _errorMessage,
            onSend: _sendResetEmail,
          ),
        ),
      ),
    );
  }
}
