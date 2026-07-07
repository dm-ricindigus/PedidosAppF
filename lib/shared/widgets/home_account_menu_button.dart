import 'package:flutter/material.dart';
import 'package:pedidosapp/features/auth/account_page.dart';

/// Menú ⋮ del home cliente: Cuenta y Cerrar sesión.
class HomeAccountMenuButton extends StatelessWidget {
  const HomeAccountMenuButton({
    super.key,
    required this.email,
    required this.iconColor,
    required this.onLogout,
  });

  final String email;
  final Color iconColor;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: iconColor),
      tooltip: 'Más opciones',
      onSelected: (value) {
        switch (value) {
          case 'account':
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AccountPage(email: email),
              ),
            );
          case 'logout':
            onLogout();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'account',
          child: Text('Cuenta'),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
