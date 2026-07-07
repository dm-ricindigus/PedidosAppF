import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pedidosapp/core/no_emoji_text_input_formatter.dart';

/// Sheet: confirmar eliminación de cuenta con contraseña.
class DeleteAccountConfirmSheet extends StatefulWidget {
  const DeleteAccountConfirmSheet({
    super.key,
    required this.email,
    required this.onCancel,
    required this.onConfirm,
  });

  final String email;
  final VoidCallback onCancel;
  final Future<void> Function(String password) onConfirm;

  @override
  State<DeleteAccountConfirmSheet> createState() =>
      _DeleteAccountConfirmSheetState();
}

class _DeleteAccountConfirmSheetState extends State<DeleteAccountConfirmSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu contraseña');
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(password);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _messageForError(e);
          _isDeleting = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }

  String _messageForError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Contraseña incorrecta';
        case 'too-many-requests':
          return 'Demasiados intentos. Inténtalo más tarde';
        case 'network-request-failed':
          return 'Sin conexión. Comprueba tu red e intenta de nuevo';
        default:
          break;
      }
    }
    if (e is FirebaseFunctionsException) {
      return e.message ?? 'No se pudo eliminar la cuenta';
    }
    final text = e.toString().replaceFirst('Exception: ', '');
    if (text.isNotEmpty && text != e.toString()) return text;
    return 'No se pudo eliminar la cuenta. Intenta de nuevo';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isDeleting,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Eliminar cuenta',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Se eliminará tu cuenta (${widget.email}) y ya no podrás '
                  'iniciar sesión. Tus pedidos se conservan para el negocio, '
                  'pero no volverán a aparecer si creas una cuenta nueva.',
                  style: TextStyle(fontSize: 15, color: scheme.onSurface),
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isDeleting,
                  autocorrect: false,
                  inputFormatters: const [NoEmojiTextInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: _isDeleting
                          ? null
                          : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  onSubmitted: _isDeleting ? null : (_) => _submit(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isDeleting ? null : widget.onCancel,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isDeleting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      child: _isDeleting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onError,
                              ),
                            )
                          : const Text('Eliminar definitivamente'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
