import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom sheet: generated order code + copy.
class AdminOrderCodeCreatedSheet extends StatelessWidget {
  const AdminOrderCodeCreatedSheet({super.key, required this.orderCode});

  final String orderCode;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Text(
                'Se creó el código de pedido:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Row(
              children: [
                const Spacer(),
                Text(
                  orderCode,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: orderCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  color: primary,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAdminOrderCodeCreatedSheet(
  BuildContext context,
  String orderCode,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AdminOrderCodeCreatedSheet(orderCode: orderCode),
  );
}

/// Generic error (create code, validation).
Future<void> showAdminErrorSheet(BuildContext context, String errorMessage) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) {
      final primary = Theme.of(ctx).colorScheme.primary;
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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

/// Sheet: client email + submit (Cloud Function called by parent).
class AdminCreateOrderCodeSheet extends StatefulWidget {
  const AdminCreateOrderCodeSheet({super.key, required this.onSubmit});

  final Future<void> Function(String email, BuildContext sheetContext) onSubmit;

  @override
  State<AdminCreateOrderCodeSheet> createState() =>
      _AdminCreateOrderCodeSheetState();
}

class _AdminCreateOrderCodeSheetState extends State<AdminCreateOrderCodeSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.onSubmit(_controller.text.trim(), context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !_loading,
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
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    hintText: 'Correo del cliente',
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
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: _loading
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

/// AppBar: Orders + admin line.
class AdminHomeAppBarTitle extends StatelessWidget {
  const AdminHomeAppBarTitle({
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

/// Filter row (compact admin padding).
class AdminOrdersFilterRow extends StatelessWidget {
  const AdminOrdersFilterRow({
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
    this.sortEnabled = true,
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
  /// When false, the sort control is non-interactive (e.g. unused order codes list).
  final bool sortEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<int>(
              initialValue: selectedFilterId,
              onSelected: onFilterSelected,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
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
                    (f) => PopupMenuItem<int>(value: f.$1, child: Text(f.$2)),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PopupMenuButton<String>(
              enabled: sortEnabled,
              initialValue: sortKey,
              onSelected: onSortSelected,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 20, color: accentColor),
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
                    (o) =>
                        PopupMenuItem<String>(value: o.$1, child: Text(o.$2)),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminOrdersEmptyInbox extends StatelessWidget {
  const AdminOrdersEmptyInbox({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay pedidos registrados',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminOrdersEmptyFilter extends StatelessWidget {
  const AdminOrdersEmptyFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay pedidos con este filtro',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
