import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pedidosapp/data/repositories/auth_repository.dart';
import 'package:pedidosapp/features/auth/widgets/register_screen_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthRepository _authRepo = AuthRepository();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    User? createdUser;
    try {
      UserCredential userCredential =
          await _authRepo.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      createdUser = userCredential.user;

      if (createdUser != null) {
        try {
          await _authRepo.createClientProfile(
            uid: createdUser.uid,
            email: _emailController.text.trim(),
          );
        } catch (firestoreError) {
          await createdUser.delete();
          rethrow;
        }

        try {
          await _authRepo.sendEmailVerification(createdUser);
        } catch (_) {
          // La cuenta existe; el usuario puede reenviar verificación desde login.
        }

        await _authRepo.signOut();
      }

      if (mounted) {
        await showRegisterEmailVerificationSheet(
          context,
          email: _emailController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al crear usuario';

      if (e.code == 'weak-password') {
        errorMessage =
            'La contraseña es muy débil. Debe tener al menos 6 caracteres';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Ya existe una cuenta con este correo electrónico';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El correo electrónico no es válido';
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
      // Si falló Firestore tras crear Auth, el usuario ya se eliminó arriba.
      String errorMessage = 'Error al crear usuario';

      if (e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('permission')) {
        errorMessage =
            'Error de permisos al guardar el perfil. Verifica las reglas de Firestore.';
      } else if (e.toString().contains('NOT_FOUND')) {
        errorMessage =
            'Base de datos no encontrada. Verifica la configuración.';
      } else {
        errorMessage = 'Error inesperado: $e';
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
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RegisterScreenHeader(),
              RegisterAccountForm(
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                confirmPasswordController: _confirmPasswordController,
                obscurePassword: _obscurePassword,
                obscureConfirmPassword: _obscureConfirmPassword,
                isLoading: _isLoading,
                onTogglePasswordVisibility: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                onToggleConfirmPasswordVisibility: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                onSubmit: _createUser,
              ),
              const SizedBox(height: 16),
              RegisterFooterLoginLink(
                isLoading: _isLoading,
                onLoginTap: () => Navigator.pop(context),
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
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
