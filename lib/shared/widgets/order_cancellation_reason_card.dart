import 'package:flutter/material.dart';

/// Motivo de cancelación visible para admin y cliente.
class OrderCancellationReasonCard extends StatelessWidget {
  const OrderCancellationReasonCard({
    super.key,
    required this.reason,
  });

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = reason.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E0E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8B4B4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: const Color(0xFF9B1C1C),
              ),
              const SizedBox(width: 8),
              Text(
                'Motivo de cancelación',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF9B1C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
