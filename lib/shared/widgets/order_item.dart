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
  if (e.contains('entregado')) {
    return (
      const Color(0xFFE8DAEF),
      const Color(0xFF6C3483),
      Icons.local_shipping_rounded,
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
  /// Correo del cliente asociado al pedido (p. ej. lista admin).
  final String? clientEmail;
  final DateTime? fechaMaxEntrega;
  /// Si se informa, se muestra como «Creado el: …» (prioridad sobre [fechaMaxEntrega]).
  final DateTime? fechaCreado;
  /// Solo número, título y línea de fecha; sin chip de estado.
  final bool hideEstadoChip;
  final VoidCallback? onTap;

  const OrderItem({
    super.key,
    required this.numeroPedido,
    required this.titulo,
    required this.estado,
    this.clientEmail,
    this.fechaMaxEntrega,
    this.fechaCreado,
    this.hideEstadoChip = false,
    this.onTap,
  });

  String _formatearFecha(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  (Color, Color, IconData) _estadoVisual(ColorScheme colorScheme) {
    return obtenerEstiloEstado(estado, colorScheme);
  }

  Widget _orderItemBody(
    BuildContext context,
    ColorScheme colorScheme,
    Color chipBg,
    Color chipFg,
    IconData chipIcon,
  ) {
    return Padding(
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
          if (clientEmail != null && clientEmail!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              clientEmail!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (fechaCreado != null) ...[
            const SizedBox(height: 4),
            Text(
              'Creado el: ${_formatearFecha(fechaCreado!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (fechaMaxEntrega != null) ...[
            const SizedBox(height: 4),
            Text(
              'Entrega máx: ${_formatearFecha(fechaMaxEntrega!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (!hideEstadoChip) ...[
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
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
        ],
      ),
    );
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
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                child: _orderItemBody(context, colorScheme, chipBg, chipFg, chipIcon),
              )
            : _orderItemBody(context, colorScheme, chipBg, chipFg, chipIcon),
      ),
    );
  }
}
