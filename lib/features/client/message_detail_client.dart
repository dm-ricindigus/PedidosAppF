import 'package:flutter/material.dart';

import 'package:pedidosapp/features/client/widgets/message_detail_client_widgets.dart';

/// Altura del sheet: deja a la vista el bloque de título del pedido bajo el AppBar
/// (mismo padding que en [OrderDetailPage]: 16+12 + fila ~40).
double _clientMessageDetailSheetHeight(BuildContext context) {
  final m = MediaQuery.sizeOf(context);
  final paddingTop = MediaQuery.paddingOf(context).top;
  const titleBlockBelowAppBar = 16.0 + 12.0 + 60.0;
  final topConsumed = paddingTop + kToolbarHeight + titleBlockBelowAppBar;
  return (m.height - topConsumed).clamp(280.0, m.height * 0.94);
}

/// Contenido del detalle de mensaje dentro del bottom sheet (scroll exterior).
class ClientMessageDetailScrollContent extends StatelessWidget {
  const ClientMessageDetailScrollContent({
    super.key,
    required this.fecha,
    required this.descripcion,
    required this.nombresArchivos,
  });

  final String fecha;
  final String descripcion;
  final List<String> nombresArchivos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClientMessageDetailMetaHeader(
          heading: 'Mensaje enviado',
          timestampText: fecha,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Text(
            descripcion,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            softWrap: true,
            textAlign: TextAlign.justify,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          nombresArchivos.isEmpty
              ? 'Este mensaje no tiene archivos adjuntos'
              : 'Archivos enviados',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (nombresArchivos.isNotEmpty)
          ClientMessageAttachmentFileList(
            fileNames: nombresArchivos,
            colorScheme: colorScheme,
            textTheme: textTheme,
            shrinkWrap: true,
          ),
      ],
    );
  }
}

/// Abre el detalle del mensaje en un modal inferior (arrastrar o X para cerrar).
Future<void> showClientMessageDetailBottomSheet(
  BuildContext context, {
  required String fecha,
  required String descripcion,
  List<String> nombresArchivos = const [],
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final sheetHeight = _clientMessageDetailSheetHeight(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height - sheetHeight,
        ),
        child: Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Cerrar',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: ClientMessageDetailScrollContent(
                      fecha: fecha,
                      descripcion: descripcion,
                      nombresArchivos: nombresArchivos,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
