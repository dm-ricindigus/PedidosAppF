import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Message row in order history (admin and client).
class OrderMessageHistoryCard extends StatelessWidget {
  const OrderMessageHistoryCard({
    super.key,
    required this.timestampLine,
    required this.bodyPreview,
    required this.attachmentCount,
    required this.onTap,
  });

  final String timestampLine;
  final String bodyPreview;
  final int attachmentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final attachLabel = attachmentCount == 0
        ? 'Sin archivos adjuntos'
        : attachmentCount == 1
            ? '1 archivo adjunto'
            : '$attachmentCount archivos adjuntos';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timestampLine,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  bodyPreview,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      attachmentCount == 0
                          ? Symbols.attach_file_off
                          : Symbols.attach_file,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      attachLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
