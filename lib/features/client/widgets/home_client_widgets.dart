import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Muestra error de validación (p. ej. código de pedido).
Future<void> showClientValidationErrorSheet(
  BuildContext context,
  String mensaje,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error de validación',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(mensaje, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Modal compacto: campo tipo píldora + botón circular (mismo patrón que admin).
class OrderCodePedidoSheet extends StatefulWidget {
  const OrderCodePedidoSheet({
    super.key,
    required this.onSubmit,
  });

  /// [sheetContext] es el context del modal (para `Navigator.pop`).
  final Future<void> Function(String codigo, BuildContext sheetContext)
      onSubmit;

  @override
  State<OrderCodePedidoSheet> createState() => _OrderCodePedidoSheetState();
}

class _OrderCodePedidoSheetState extends State<OrderCodePedidoSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(_controller.text.trim(), context);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final canSubmit = !_isLoading && _controller.text.length == 8;

    return PopScope(
      canPop: !_isLoading,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
            top: 16.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  enabled: !_isLoading,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    hintText: 'Código de pedido',
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: !canSubmit ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título del AppBar (Pedidos + email).
class ClientHomeAppBarTitle extends StatelessWidget {
  const ClientHomeAppBarTitle({
    super.key,
    required this.userInfo,
    required this.onAccentColor,
  });

  final String userInfo;
  final Color onAccentColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Pedidos',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: onAccentColor,
          ),
        ),
        Text(
          userInfo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
        ),
      ],
    );
  }
}

/// Fila de filtros (estado + orden).
class ClientOrdersFilterRow extends StatelessWidget {
  const ClientOrdersFilterRow({
    super.key,
    required this.stateFilterOptions,
    required this.sortOptions,
    required this.selectedFilterId,
    required this.sortKey,
    required this.filterLabel,
    required this.sortLabel,
    required this.onFilterSelected,
    required this.onSortSelected,
    required this.accentColor,
  });

  final List<(int, String)> stateFilterOptions;
  final List<(String, String)> sortOptions;
  final int selectedFilterId;
  final String sortKey;
  final String filterLabel;
  final String sortLabel;
  final ValueChanged<int> onFilterSelected;
  final ValueChanged<String> onSortSelected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<int>(
              initialValue: selectedFilterId,
              onSelected: onFilterSelected,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filterLabel,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => stateFilterOptions
                  .map(
                    (f) => PopupMenuItem<int>(
                      value: f.$1,
                      child: Text(f.$2),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PopupMenuButton<String>(
              initialValue: sortKey,
              onSelected: onSortSelected,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 20,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sortLabel,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => sortOptions
                  .map(
                    (o) => PopupMenuItem<String>(
                      value: o.$1,
                      child: Text(o.$2),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista vacía inicial.
class ClientOrdersEmptyInbox extends StatelessWidget {
  const ClientOrdersEmptyInbox({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes pedidos aún',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer pedido',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Sin resultados tras filtrar.
class ClientOrdersEmptyFilter extends StatelessWidget {
  const ClientOrdersEmptyFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay pedidos con este filtro',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
