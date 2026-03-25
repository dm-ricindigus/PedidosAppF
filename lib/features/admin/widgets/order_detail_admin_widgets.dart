import 'package:flutter/material.dart';

import 'package:pedidosapp/shared/widgets/order_item.dart';

/// State chip + max delivery date line.
class OrderDetailAdminStateHeader extends StatelessWidget {
  const OrderDetailAdminStateHeader({
    super.key,
    required this.currentStateLabel,
    required this.maxDeliveryLabel,
    required this.chipBackground,
    required this.chipForeground,
    required this.chipIcon,
    required this.textTheme,
    required this.onSurfaceVariant,
    required this.onTapChangeState,
  });

  final String currentStateLabel;
  final String maxDeliveryLabel;
  final Color chipBackground;
  final Color chipForeground;
  final IconData chipIcon;
  final TextTheme textTheme;
  final Color onSurfaceVariant;
  final VoidCallback onTapChangeState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTapChangeState,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(chipIcon, size: 20, color: chipForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentStateLabel,
                      style: textTheme.titleSmall?.copyWith(
                        color: chipForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: chipForeground),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_rounded, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  maxDeliveryLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAdminOrderStateConfirmSheet(
  BuildContext context, {
  required String newStateLabel,
  required Future<void> Function(BuildContext sheetContext) onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cambiaras el estado a $newStateLabel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text('¿Estas Seguro?', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('No'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await onConfirm(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Sí'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showAdminOrderStatePickerSheet(
  BuildContext context, {
  required List<String> stateLabels,
  required String currentStateLabel,
  required void Function(String newStateLabel) onStateSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Seleccionar Estado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...stateLabels.map((label) {
              final (_, colorFg, iconData) = obtenerEstiloEstado(label, scheme);
              return ListTile(
                leading: Icon(iconData, size: 22, color: colorFg),
                title: Text(
                  label,
                  style: TextStyle(color: colorFg, fontWeight: FontWeight.w600),
                ),
                trailing: currentStateLabel == label
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (label == currentStateLabel) return;
                  onStateSelected(label);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
