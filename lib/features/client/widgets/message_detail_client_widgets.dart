import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Título de sección + fecha del mensaje (detalle cliente).
class ClientMessageDetailMetaHeader extends StatelessWidget {
  const ClientMessageDetailMetaHeader({
    super.key,
    required this.heading,
    required this.timestampText,
    required this.colorScheme,
    required this.textTheme,
  });

  final String heading;
  final String timestampText;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          timestampText,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Lista de nombres de archivos enviados (solo lectura).
class ClientMessageAttachmentFileList extends StatelessWidget {
  const ClientMessageAttachmentFileList({
    super.key,
    required this.fileNames,
    required this.colorScheme,
    required this.textTheme,
    this.shrinkWrap = false,
  });

  final List<String> fileNames;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  /// En un [SingleChildScrollView] padre, usar `true` y scroll solo del padre.
  final bool shrinkWrap;

  static String _baseName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) return fileName;
    return fileName.substring(0, dotIndex);
  }

  static String _typeLabel(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return 'archivo';
    }
    return 'archivo.${fileName.substring(dotIndex + 1)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: fileNames.length,
      itemBuilder: (context, index) {
        final fileName = fileNames[index];
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _baseName(fileName),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _typeLabel(fileName),
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
    );
  }
}
