import 'package:flutter/material.dart';

/// Retorna (colorFondo, colorTexto, icono) para el estado dado.
(Color, Color, IconData) obtenerEstiloEstado(
  String estado,
  ColorScheme colorScheme,
) {
  final e = estado.toLowerCase();
  if (e.contains('ingresado')) {
    return (
      const Color(0xFFDDEBFF),
      const Color(0xFF1E4FA3),
      Icons.edit_note_rounded,
    );
  }
  if (e.contains('impresión') || e.contains('transferencia')) {
    return (
      const Color(0xFFE4E6EB),
      const Color(0xFF2F3640),
      Icons.print_rounded,
    );
  }
  if (e.contains('confección')) {
    return (
      const Color(0xFFDDF5E3),
      const Color(0xFF1E6B36),
      Icons.design_services_rounded,
    );
  }
  if (e.contains('acabados')) {
    return (
      const Color(0xFFF8DDE1),
      const Color(0xFF8A1F2D),
      Icons.check_circle_rounded,
    );
  }
  if (e.contains('empacado')) {
    return (
      const Color(0xFFF2E3D5),
      const Color(0xFF6B3F1E),
      Icons.inventory_2_rounded,
    );
  }
  return (
    colorScheme.surfaceContainerHighest,
    colorScheme.onSurfaceVariant,
    Icons.help_outline_rounded,
  );
}

class OrderItem extends StatelessWidget {
  final String numeroPedido;
  final String titulo;
  final String estado;
  final VoidCallback? onTap;

  const OrderItem({
    super.key,
    required this.numeroPedido,
    required this.titulo,
    required this.estado,
    this.onTap,
  });

  (Color, Color, IconData) _estadoVisual(ColorScheme colorScheme) {
    return obtenerEstiloEstado(estado, colorScheme);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (chipBg, chipFg, chipIcon) = _estadoVisual(colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numeroPedido,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  titulo,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(chipIcon, size: 16, color: chipFg),
                          const SizedBox(width: 6),
                          Text(
                            estado,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: chipFg,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
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
