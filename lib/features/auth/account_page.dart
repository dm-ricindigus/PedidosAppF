import 'package:flutter/material.dart';
import 'package:pedidosapp/data/repositories/auth_repository.dart';
import 'package:pedidosapp/features/auth/login.dart';
import 'package:pedidosapp/features/auth/widgets/delete_account_confirm_sheet.dart';

/// Pantalla de cuenta del cliente.
class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.email,
  });

  final String email;

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final authRepo = AuthRepository();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => DeleteAccountConfirmSheet(
        email: email,
        onCancel: () => Navigator.pop(sheetContext),
        onConfirm: (password) async {
          await authRepo.deleteClientAccount(password: password);
          if (!sheetContext.mounted) return;
          Navigator.pop(sheetContext);
          if (!context.mounted) return;
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginPage(title: 'Login'),
            ),
            (route) => false,
          );
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Tu cuenta ha sido eliminada'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                      Icons.account_circle,
                      size: 56,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuenta Cliente',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeleteAccount(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.person_off),
                label: const Text('Eliminar cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
