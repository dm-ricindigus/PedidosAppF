import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:pedidosapp/features/admin/admin_mark_order_paid_flow.dart';
import 'package:pedidosapp/features/admin/message_detail_admin.dart';
import 'package:pedidosapp/features/admin/widgets/order_detail_admin_widgets.dart';
import 'package:pedidosapp/shared/message_read_utils.dart';
import 'package:pedidosapp/shared/order_states.dart';
import 'package:pedidosapp/shared/widgets/order_cancellation_reason_card.dart';
import 'package:pedidosapp/shared/widgets/order_item.dart';
import 'package:pedidosapp/shared/widgets/order_message_history_card.dart';

class OrderDetailAdminPage extends StatefulWidget {
  final String orderDisplayLine;
  final String title;
  final String? initialStateLabel;

  /// ID del documento en `orders` (evita consultas por código bloqueadas en admin demo).
  final String? initialOrderId;

  const OrderDetailAdminPage({
    super.key,
    required this.orderDisplayLine,
    required this.title,
    this.initialStateLabel,
    this.initialOrderId,
  });

  @override
  State<OrderDetailAdminPage> createState() => _OrderDetailAdminPageState();
}

class _OrderDetailAdminPageState extends State<OrderDetailAdminPage> {
  final OrdersRepository _ordersRepo = OrdersRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey _adminOrderAppBarKey = GlobalKey();
  late String _currentStateLabel;
  int _currentStateCode = kOrderStateIngresado;
  String? _orderId;
  String? _clientEmail;
  String? _cancellationReason;
  Timestamp? _maxDeliveryDate;
  bool _loadingOrder = true;
  bool _isPaid = false;

  String? get _resolvedOrderId {
    final fromState = _orderId?.trim();
    if (fromState != null && fromState.isNotEmpty) return fromState;
    final fromRoute = widget.initialOrderId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    return null;
  }

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

  void _openAdminMessageDetailSheet(
    String messageId, {
    required bool markReadIfUnread,
  }) {
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

    if (!markReadIfUnread) return;

    final orderId = _resolvedOrderId;
    if (orderId == null) return;

    unawaited(
      _ordersRepo
          .markMessageReadByAdmin(messageId: messageId, orderId: orderId)
          .catchError((Object e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo marcar el mensaje como leído: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentStateLabel =
        widget.initialStateLabel ?? kOrderPipelineStateLabels.first;
    _loadOrder();
  }

  String _parseOrderCodeFromDisplayLine(String displayLine) {
    return displayLine.replaceAll('Pedido Nº', '').trim();
  }

  String _labelForStateCode(int? state) => orderStateLabel(state);

  int _stateCodeForLabel(String label) => orderStateCodeForLabel(label);

  bool get _isStateChangeEnabled => !isOrderCancelled(_currentStateCode);

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
    try {
      DocumentSnapshot<Map<String, dynamic>>? orderDoc;

      final initialOrderId = widget.initialOrderId?.trim();
      if (initialOrderId != null && initialOrderId.isNotEmpty) {
        orderDoc = await _ordersRepo.getOrder(initialOrderId);
        if (!orderDoc.exists) {
          orderDoc = null;
        }
      } else {
        final orderCode = _parseOrderCodeFromDisplayLine(
          widget.orderDisplayLine,
        );
        final orderQuery = await _ordersRepo.ordersByCode(orderCode);
        if (orderQuery.docs.isNotEmpty) {
          orderDoc = orderQuery.docs.first;
        }
      }

      if (!mounted) return;

      if (orderDoc == null || !orderDoc.exists) {
        setState(() {
          _orderId = null;
          _clientEmail = null;
          _loadingOrder = false;
        });
        return;
      }

      final orderData = orderDoc.data()!;
      final state = orderData[FirestoreFields.state] as int?;
      final maxDeliveryDate =
          orderData[FirestoreFields.maxDeliveryDate] as Timestamp?;
      final rawEmail = orderData[FirestoreFields.clientEmail];
      final emailStr = rawEmail == null ? '' : rawEmail.toString().trim();
      final clientEmail = emailStr.isNotEmpty ? emailStr : null;
      final cancellationReason =
          (orderData[FirestoreFields.cancellationReason] as String?)?.trim();
      final isPaid = orderData[FirestoreFields.isPaid] == true;

      setState(() {
        _orderId = orderDoc!.id;
        _clientEmail = clientEmail;
        _currentStateCode = state ?? kOrderStateIngresado;
        _currentStateLabel = _labelForStateCode(state);
        _maxDeliveryDate = maxDeliveryDate;
        _cancellationReason =
            (cancellationReason != null && cancellationReason.isNotEmpty)
            ? cancellationReason
            : null;
        _isPaid = isPaid;
        _loadingOrder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOrder = false;
        _orderId = null;
        _clientEmail = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar el pedido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onStateSelected(String newStateLabel) {
    if (newStateLabel == kOrderStateCanceladoLabel) {
      _showCancelOrderSheet();
      return;
    }
    _showStateChangeConfirmSheet(newStateLabel);
  }

  void _showCancelOrderSheet() {
    showAdminOrderCancelSheet(
      context,
      onConfirm: (reason, sheetContext) async {
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

        final adminUid = _auth.currentUser?.uid;
        if (adminUid == null) {
          if (sheetContext.mounted) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              const SnackBar(
                content: Text('Sesión no válida'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        try {
          await _ordersRepo.cancelOrder(
            orderId: _orderId!,
            reason: reason,
            cancelledByUid: adminUid,
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al cancelar el pedido'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (!mounted) return;
        setState(() {
          _currentStateLabel = kOrderStateCanceladoLabel;
          _currentStateCode = kOrderStateCancelado;
          _cancellationReason = reason;
        });
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        await _loadOrder();
      },
    );
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
          _currentStateCode = newStateCode;
        });
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        await _loadOrder();
      },
    );
  }

  void _showDeleteOrderSheet() {
    showAdminDeleteOrderConfirmSheet(
      context,
      orderDisplayLine: widget.orderDisplayLine,
      onConfirm: (sheetContext) async {
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

        try {
          await _ordersRepo.deleteCancelledOrder(orderId: _orderId!);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar el pedido'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (!mounted) return;
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pedido eliminado')));
      },
    );
  }

  void _markOrderAsPaid() {
    final orderId = _orderId;
    if (orderId == null || _isPaid) return;

    runAdminMarkOrderAsPaidFlow(
      context,
      ordersRepo: _ordersRepo,
      adminUid: _auth.currentUser?.uid,
      orderId: orderId,
      orderDisplayLine: widget.orderDisplayLine,
      onSuccess: () {
        if (mounted) {
          setState(() => _isPaid = true);
        }
      },
    );
  }

  void _showStatePickerSheet() {
    if (!_isStateChangeEnabled) return;

    showAdminOrderStatePickerSheet(
      context,
      pipelineStateLabels: kOrderPipelineStateLabels,
      cancelStateLabel: canCancelOrder(_currentStateCode)
          ? kOrderStateCanceladoLabel
          : null,
      currentStateLabel: _currentStateLabel,
      onStateSelected: _onStateSelected,
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
        actions: [
          if (!_loadingOrder && _orderId != null && !_isPaid)
            IconButton(
              tooltip: 'Marcar como pagado',
              onPressed: _markOrderAsPaid,
              icon: const Icon(Icons.paid_outlined),
            ),
          if (!_loadingOrder && _orderId != null && _isPaid)
            IconButton(
              tooltip: 'Pagado',
              onPressed: null,
              icon: const Icon(Icons.paid_rounded),
            ),
          if (isOrderCancelled(_currentStateCode))
            IconButton(
              tooltip: 'Eliminar pedido',
              onPressed: _loadingOrder || _orderId == null
                  ? null
                  : _showDeleteOrderSheet,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
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
            onTapChangeState: _isStateChangeEnabled
                ? _showStatePickerSheet
                : null,
            clientEmail: (!_loadingOrder && _orderId != null)
                ? _clientEmail
                : null,
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

                        final messageDocs = snapshot.hasData
                            ? snapshot.data!.docs
                            : <QueryDocumentSnapshot>[];
                        final hasCancellationReason =
                            (_cancellationReason ?? '').trim().isNotEmpty;

                        if (messageDocs.isEmpty && !hasCancellationReason) {
                          return Center(
                            child: Text(
                              'No hay mensajes aún',
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            if (messageDocs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'No hay mensajes aún',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ...messageDocs.map((messageDoc) {
                              final data =
                                  messageDoc.data() as Map<String, dynamic>;
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
                                isUnread: isMessageUnreadByAdmin(data),
                                onTap: () => _openAdminMessageDetailSheet(
                                  messageDoc.id,
                                  markReadIfUnread: isMessageUnreadByAdmin(data),
                                ),
                              );
                            }),
                            if (hasCancellationReason)
                              OrderCancellationReasonCard(
                                reason: _cancellationReason!,
                              ),
                          ],
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
