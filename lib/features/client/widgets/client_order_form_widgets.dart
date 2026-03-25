import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

// ——— Modelos ———

enum EstadoAdjunto { pending, uploading, uploaded, failed }

class ArchivoAdjunto {
  final PlatformFile file;
  EstadoAdjunto estado;
  String? urlDescarga;
  String? rutaStorage;
  String? error;

  ArchivoAdjunto({
    required this.file,
    this.estado = EstadoAdjunto.pending,
    this.urlDescarga,
    this.rutaStorage,
    this.error,
  });
}

// ——— Borde punteado (zona de adjuntos) ———

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.borderRadius = 12.0,
  });

  final Color color;
  final double strokeWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          (distance + dashWidth).clamp(0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fila de archivo con botón eliminar.
class OrderAttachmentFileRow extends StatelessWidget {
  const OrderAttachmentFileRow({
    super.key,
    required this.fileName,
    required this.onDelete,
    this.iconSize = 22,
  });

  final String fileName;
  final VoidCallback? onDelete;
  final double iconSize;

  String _acortarEnMedio(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    if (maxLength <= 3) return text.substring(0, maxLength);
    final int charsDisponibles = maxLength - 3;
    final int inicio = (charsDisponibles / 2).ceil();
    final int fin = charsDisponibles - inicio;
    return '${text.substring(0, inicio)}...${text.substring(text.length - fin)}';
  }

  String _nombreArchivoCorto(String original, {int maxLength = 32}) {
    if (original.length <= maxLength) return original;
    final dotIndex = original.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == original.length - 1) {
      return _acortarEnMedio(original, maxLength);
    }
    final String base = original.substring(0, dotIndex);
    final String extension = original.substring(dotIndex);
    final int maxBaseLength = maxLength - extension.length;
    if (maxBaseLength <= 3) return _acortarEnMedio(original, maxLength);
    return '${_acortarEnMedio(base, maxBaseLength)}$extension';
  }

  @override
  Widget build(BuildContext context) {
    final nombreVisible = _nombreArchivoCorto(fileName);

    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 4),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: Colors.grey.shade400,
          strokeWidth: 1.0,
          borderRadius: 8.0,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  nombreVisible,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: onDelete == null ? Colors.grey[400] : Colors.grey[700],
                ),
                iconSize: iconSize,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(24),
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder cuando no hay archivos.
class OrderAttachmentsEmptyPlaceholder extends StatelessWidget {
  const OrderAttachmentsEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: Colors.grey.shade400,
                strokeWidth: 1.0,
                borderRadius: 12.0,
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.attach_file_off,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay archivos adjuntos',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ——— Bottom sheets ———

/// Sheet bloqueante con progreso (guardar pedido / enviar mensaje).
Future<void> showOrderFormProgressSheet(
  BuildContext context, {
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return PopScope(
        canPop: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Sheet de éxito genérico (nuevo pedido / mensaje enviado).
Future<void> showOrderFormSuccessSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  IconData icon = Icons.check_circle_outline_rounded,
  Color? iconColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final effectiveIconColor = iconColor ?? scheme.primary;

      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: effectiveIconColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
