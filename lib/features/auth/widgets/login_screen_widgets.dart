import 'package:flutter/material.dart';

/// Marca en la pantalla de login (logo horizontal).
class LoginBrandingTitle extends StatelessWidget {
  const LoginBrandingTitle({super.key});

  static const String _logoAsset = 'assets/images/tsm_logo_color.png';

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 48;
    return SizedBox(
      width: maxWidth,
      child: Image.asset(
        _logoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'The Shoes Magic',
      ),
    );
  }
}

/// Formulario correo + contraseña + botón ingresar.
class LoginCredentialsForm extends StatelessWidget {
  const LoginCredentialsForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.emailErrorText,
    required this.passwordErrorText,
    required this.onEmailEdited,
    required this.onPasswordEdited,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final String? emailErrorText;
  final String? passwordErrorText;
  final VoidCallback onEmailEdited;
  final VoidCallback onPasswordEdited;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            onChanged: (_) => onEmailEdited(),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'ejemplo@correo.com',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              errorText: emailErrorText,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            enabled: !isLoading,
            onChanged: (_) => onPasswordEdited(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Ingresa tu contraseña',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: isLoading ? null : onTogglePasswordVisibility,
              ),
              errorText: passwordErrorText,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Ingresar',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enlaces "Recuperar contraseña" y fila "No tienes usuario? / Registrate".
class LoginSecondaryActions extends StatelessWidget {
  const LoginSecondaryActions({
    super.key,
    required this.isLoading,
    required this.onRecoverPassword,
    required this.onGoRegister,
  });

  final bool isLoading;
  final Future<void> Function() onRecoverPassword;
  final VoidCallback onGoRegister;

  static ButtonStyle get _linkButtonStyle => ButtonStyle(
    padding: WidgetStateProperty.all(EdgeInsets.zero),
    minimumSize: WidgetStateProperty.all(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
    overlayColor: WidgetStateProperty.all(Colors.transparent),
  );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: isLoading
              ? null
              : () {
                  onRecoverPassword();
                },
          style: _linkButtonStyle,
          child: Text(
            'Recuperar contraseña',
            style: TextStyle(decorationColor: primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'No tienes usuario?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: isLoading ? null : onGoRegister,
              style: _linkButtonStyle,
              child: Text(
                'Registrate',
                style: TextStyle(decorationColor: primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet: correo no verificado.
class LoginEmailVerificationSheet extends StatefulWidget {
  const LoginEmailVerificationSheet({super.key, required this.onResend});

  final Future<void> Function() onResend;

  @override
  State<LoginEmailVerificationSheet> createState() =>
      _LoginEmailVerificationSheetState();
}

class _LoginEmailVerificationSheetState
    extends State<LoginEmailVerificationSheet> {
  bool _sending = false;

  Future<void> _handleResend() async {
    setState(() => _sending = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo de verificación enviado'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo reenviar. Intenta más tarde.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_unread_rounded,
              color: colorScheme.primary,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Verifica tu correo',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Debes verificar tu correo electrónico antes de iniciar sesión. Revisa tu bandeja de entrada, spam y promociones.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _sending ? null : _handleResend,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Enviando...' : 'Reenviar correo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet tras enviar correo de recuperación.
class RecoverPasswordEmailSentSheet extends StatelessWidget {
  const RecoverPasswordEmailSentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Te enviamos un enlace para cambiar tu contraseña. Revisa bandeja de entrada, spam y promociones.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuerpo scrollable de [RecoverPasswordPage].
class RecoverPasswordFormContent extends StatelessWidget {
  const RecoverPasswordFormContent({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.isSending,
    required this.errorMessage,
    required this.onSend,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSending;
  final String? errorMessage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
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
          Icon(Icons.lock_reset, size: 56, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                errorMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isSending,
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
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(isSending ? 'Enviando...' : 'Enviar enlace'),
            ),
          ),
        ],
      ),
    );
  }
}
