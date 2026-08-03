import 'package:flutter/material.dart';

import 'package:pedidosapp/core/no_emoji_text_input_formatter.dart';
import 'package:pedidosapp/shared/order_states.dart';
import 'package:pedidosapp/shared/widgets/order_item.dart';

/// State chip + max delivery date line + correo del cliente (opcional).
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
    this.clientEmail,
  });

  final String currentStateLabel;
  final String maxDeliveryLabel;
  final Color chipBackground;
  final Color chipForeground;
  final IconData chipIcon;
  final TextTheme textTheme;
  final Color onSurfaceVariant;
  final VoidCallback? onTapChangeState;
  /// Solo el texto del correo (seleccionable); si es null o vacío no se muestra fila.
  final String? clientEmail;

  @override
  Widget build(BuildContext context) {
    final email = clientEmail?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onTapChangeState != null)
            InkWell(
              onTap: onTapChangeState,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
            )
          else
            Container(
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
                ],
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  SelectableText(
                    email,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAdminDeleteOrderConfirmSheet(
  BuildContext context, {
  required String orderDisplayLine,
  required Future<void> Function(BuildContext sheetContext) onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;

      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    size: 40,
                    color: Color(0xFF9B1C1C),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Eliminar pedido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Se eliminará $orderDisplayLine y todo su historial. '
                    'Esta acción no se puede deshacer.',
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
                        child: _AdminDeleteOrderConfirmButton(
                          onConfirm: () => onConfirm(sheetContext),
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
    },
  );
}

class _AdminDeleteOrderConfirmButton extends StatefulWidget {
  const _AdminDeleteOrderConfirmButton({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_AdminDeleteOrderConfirmButton> createState() =>
      _AdminDeleteOrderConfirmButtonState();
}

class _AdminDeleteOrderConfirmButtonState
    extends State<_AdminDeleteOrderConfirmButton> {
  bool _isDeleting = false;

  Future<void> _submit() async {
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isDeleting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9B1C1C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _isDeleting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Sí, eliminar'),
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

Future<void> showAdminOrderCancelSheet(
  BuildContext context, {
  required Future<void> Function(String reason, BuildContext sheetContext)
  onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _AdminOrderCancelSheet(onConfirm: onConfirm);
    },
  );
}

class _AdminOrderCancelSheet extends StatefulWidget {
  const _AdminOrderCancelSheet({required this.onConfirm});

  final Future<void> Function(String reason, BuildContext sheetContext)
  onConfirm;

  @override
  State<_AdminOrderCancelSheet> createState() => _AdminOrderCancelSheetState();
}

class _AdminOrderCancelSheetState extends State<_AdminOrderCancelSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? _validateReason(String value) {
    final trimmed = value.trim();
    if (trimmed.length < kOrderCancellationReasonMinLength) {
      return 'Ingresa al menos $kOrderCancellationReasonMinLength caracteres';
    }
    if (trimmed.length > kOrderCancellationReasonMaxLength) {
      return 'Máximo $kOrderCancellationReasonMaxLength caracteres';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validateReason(_reasonController.text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      await widget.onConfirm(_reasonController.text.trim(), context);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cancelar pedido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Indica el motivo de la cancelación (mínimo '
                  '$kOrderCancellationReasonMinLength caracteres).',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: kOrderCancellationReasonMaxLength,
                  enabled: !_isSubmitting,
                  inputFormatters: const [NoEmojiTextInputFormatter()],
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Motivo de cancelación',
                    errorText: _errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B1C1C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirmar'),
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

void showAdminOrderStatePickerSheet(
  BuildContext context, {
  required List<String> pipelineStateLabels,
  required String currentStateLabel,
  required void Function(String newStateLabel) onStateSelected,
  String? cancelStateLabel,
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
            ...pipelineStateLabels.map((label) {
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
            if (cancelStateLabel != null) ...[
              const Divider(height: 1),
              Builder(
                builder: (context) {
                  final (_, colorFg, iconData) = obtenerEstiloEstado(
                    cancelStateLabel,
                    scheme,
                  );
                  return ListTile(
                    leading: Icon(iconData, size: 22, color: colorFg),
                    title: Text(
                      cancelStateLabel,
                      style: TextStyle(
                        color: colorFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: currentStateLabel == cancelStateLabel
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (cancelStateLabel == currentStateLabel) return;
                      onStateSelected(cancelStateLabel);
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
