import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:pedidosapp/features/admin/message_detail_admin.dart';
import 'package:pedidosapp/features/admin/widgets/order_detail_admin_widgets.dart';
import 'package:pedidosapp/shared/widgets/order_item.dart';
import 'package:pedidosapp/shared/widgets/order_message_history_card.dart';

class OrderDetailAdminPage extends StatefulWidget {
  final String orderDisplayLine;
  final String title;
  final String? initialStateLabel;

  const OrderDetailAdminPage({
    super.key,
    required this.orderDisplayLine,
    required this.title,
    this.initialStateLabel,
  });

  @override
  State<OrderDetailAdminPage> createState() => _OrderDetailAdminPageState();
}

class _OrderDetailAdminPageState extends State<OrderDetailAdminPage> {
  final OrdersRepository _ordersRepo = OrdersRepository();
  final GlobalKey _adminOrderAppBarKey = GlobalKey();
  late String _currentStateLabel;
  String? _orderId;
  Timestamp? _maxDeliveryDate;
  bool _loadingOrder = true;

  /// Borde inferior del AppBar en coordenadas globales (para alinear el sheet).
  double _messageDetailSheetTopInsetPx() {
    final box =
        _adminOrderAppBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached && box.hasSize) {
      return box.localToGlobal(Offset(0, box.size.height)).dy;
    }
    return MediaQuery.viewPaddingOf(context).top +
        kOrderDetailAdminAppBarToolbarHeight;
  }

  void _openAdminMessageDetailSheet(String messageId) {
    void open() {
      if (!mounted) return;
      showAdminMessageDetailBottomSheet(
        context,
        messageId: messageId,
        sheetTopInset: _messageDetailSheetTopInsetPx(),
        appBarToolbarHeight: kOrderDetailAdminAppBarToolbarHeight,
      );
    }

    final box =
        _adminOrderAppBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
    } else {
      open();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentStateLabel = widget.initialStateLabel ?? _pipelineStateLabels.first;
    _loadOrder();
  }

  final List<String> _pipelineStateLabels = [
    'Ingresado',
    'Impresión y Transferencia',
    'Confección',
    'Acabados',
    'Empacado',
    'Entregado',
  ];

  String _parseOrderCodeFromDisplayLine(String displayLine) {
    return displayLine.replaceAll('Pedido Nº', '').trim();
  }

  String _labelForStateCode(int? state) {
    if (state == null || state < 1 || state > _pipelineStateLabels.length) {
      return _pipelineStateLabels.first;
    }
    return _pipelineStateLabels[state - 1];
  }

  int _stateCodeForLabel(String label) {
    final index = _pipelineStateLabels.indexOf(label);
    return index == -1 ? 1 : index + 1;
  }

  String _formatMessageTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha no disponible';

    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'pm' : 'am';

    return '$day/$month/$year - $hour:$minute$amPm';
  }

  String _formatShortDate(Timestamp? timestamp) {
    if (timestamp == null) return 'No disponible';
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _loadOrder() async {
    final orderCode = _parseOrderCodeFromDisplayLine(widget.orderDisplayLine);

    try {
      final orderQuery = await _ordersRepo.ordersByCode(orderCode);

      if (!mounted) return;

      if (orderQuery.docs.isEmpty) {
        setState(() {
          _orderId = null;
          _loadingOrder = false;
        });
        return;
      }

      final orderDoc = orderQuery.docs.first;
      final orderData = orderDoc.data();
      final state = orderData[FirestoreFields.state] as int?;
      final maxDeliveryDate =
          orderData[FirestoreFields.maxDeliveryDate] as Timestamp?;

      setState(() {
        _orderId = orderDoc.id;
        _currentStateLabel = _labelForStateCode(state);
        _maxDeliveryDate = maxDeliveryDate;
        _loadingOrder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar el pedido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStateChangeConfirmSheet(String newStateLabel) {
    showAdminOrderStateConfirmSheet(
      context,
      newStateLabel: newStateLabel,
      onConfirm: (sheetContext) async {
        if (newStateLabel == _currentStateLabel) {
          Navigator.pop(sheetContext);
          return;
        }

        if (_orderId == null) {
          if (sheetContext.mounted) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(
                content: Text('No se encontro el pedido'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final newStateCode = _stateCodeForLabel(newStateLabel);

        try {
          await _ordersRepo.updateOrderState(
            orderId: _orderId!,
            state: newStateCode,
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al actualizar el estado'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (!mounted) return;
        setState(() {
          _currentStateLabel = newStateLabel;
        });
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        await _loadOrder();
      },
    );
  }

  void _showStatePickerSheet() {
    showAdminOrderStatePickerSheet(
      context,
      stateLabels: _pipelineStateLabels,
      currentStateLabel: _currentStateLabel,
      onStateSelected: _showStateChangeConfirmSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final Color accentColor = theme.colorScheme.primary;
    const Color onAccentColor = Colors.white;
    final (chipBg, chipFg, chipIcon) = obtenerEstiloEstado(
      _currentStateLabel,
      theme.colorScheme,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        key: _adminOrderAppBarKey,
        toolbarHeight: kOrderDetailAdminAppBarToolbarHeight,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        backgroundColor: accentColor,
        foregroundColor: onAccentColor,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.orderDisplayLine,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: onAccentColor,
              ),
            ),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: onAccentColor),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          OrderDetailAdminStateHeader(
            currentStateLabel: _currentStateLabel,
            maxDeliveryLabel:
                'Fecha máxima de entrega: ${_formatShortDate(_maxDeliveryDate)}',
            chipBackground: chipBg,
            chipForeground: chipFg,
            chipIcon: chipIcon,
            textTheme: textTheme,
            onSurfaceVariant: theme.colorScheme.onSurfaceVariant,
            onTapChangeState: _showStatePickerSheet,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loadingOrder
                  ? const Center(child: CircularProgressIndicator())
                  : _orderId == null
                  ? const Center(child: Text('No se encontro el pedido'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _ordersRepo.watchMessagesForOrder(_orderId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error al cargar mensajes: ${snapshot.error}',
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No hay mensajes aún',
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        final messageDocs = snapshot.data!.docs;

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: messageDocs.length,
                          itemBuilder: (context, index) {
                            final data =
                                messageDocs[index].data()
                                    as Map<String, dynamic>;
                            final timestampLine = _formatMessageTimestamp(
                              data[FirestoreFields.createdAt] as Timestamp?,
                            );
                            final bodyPreview =
                                (data[FirestoreFields.message] as String?) ??
                                '';
                            final attachments =
                                (data[FirestoreFields.attachments]
                                    as List<dynamic>?) ??
                                [];

                            return OrderMessageHistoryCard(
                              timestampLine: timestampLine,
                              bodyPreview: bodyPreview,
                              attachmentCount: attachments.length,
                              onTap: () => _openAdminMessageDetailSheet(
                                messageDocs[index].id,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
