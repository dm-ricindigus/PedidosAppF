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
    this.isUnread = false,
  });

  final String timestampLine;
  final String bodyPreview;
  final int attachmentCount;
  final VoidCallback onTap;
  final bool isUnread;

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
          color: isUnread
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isUnread
                ? BorderSide(color: colorScheme.primary.withValues(alpha: 0.4))
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        timestampLine,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w400,
                            ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Nuevo',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  bodyPreview,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
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
