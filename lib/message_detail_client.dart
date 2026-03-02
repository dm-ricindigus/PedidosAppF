import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MessageDetailClientPage extends StatelessWidget {
  final String fecha;
  final String descripcion;
  final int cantidadArchivos;
  final List<String> nombresArchivos;
  final String numeroPedido;
  final String estado;

  const MessageDetailClientPage({
    super.key,
    required this.fecha,
    required this.descripcion,
    required this.cantidadArchivos,
    this.nombresArchivos = const [],
    required this.numeroPedido,
    required this.estado,
  });

  String _nombreSinExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return fileName;
    return fileName.substring(0, dotIndex);
  }

  String _extensionArchivo(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final Color accentColor = colorScheme.primary;
    const Color onAccentColor = Colors.white;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        titleSpacing: 16,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              numeroPedido,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: onAccentColor,
              ),
            ),
            Text(
              'Estado: $estado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
            ),
          ],
        ),
        actions: [const SizedBox(width: 48)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensaje enviado',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 168,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  descripcion,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  softWrap: true,
                  textAlign: TextAlign.justify,
                ),
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
            Expanded(
              child: nombresArchivos.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      itemCount: nombresArchivos.length,
                      itemBuilder: (context, index) {
                        final isFirst = index == 0;
                        final fileName = nombresArchivos[index];
                        final nombreSinExtension = _nombreSinExtension(
                          fileName,
                        );
                        final extension = _extensionArchivo(fileName);
                        return Column(
                          children: [
                            if (!isFirst)
                              Divider(
                                color: colorScheme.outlineVariant,
                                height: 1,
                                thickness: 1,
                              ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.file_export,
                                    size: 20,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombreSinExtension,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          extension.isEmpty
                                              ? 'archivo'
                                              : 'archivo.$extension',
                                          style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
