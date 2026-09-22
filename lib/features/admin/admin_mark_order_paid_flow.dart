import 'package:flutter/material.dart';
import 'package:pedidosapp/data/repositories/orders_repository.dart';
import 'package:pedidosapp/features/admin/widgets/home_admin_widgets.dart';

/// Confirmación y escritura en Firestore para marcar un pedido como pagado (solo admin).
Future<void> runAdminMarkOrderAsPaidFlow(
  BuildContext context, {
  required OrdersRepository ordersRepo,
  required String? adminUid,
  required String orderId,
  required String orderDisplayLine,
  VoidCallback? onSuccess,
}) {
  return showAdminOrderPaidConfirmSheet(
    context,
    orderDisplayLine: orderDisplayLine,
    onConfirm: (sheetContext) async {
      if (adminUid == null || adminUid.isEmpty) {
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión no válida'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      try {
        await ordersRepo.markOrderAsPaid(
          orderId: orderId,
          adminUid: adminUid,
        );
      } catch (_) {
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo marcar el pedido como pagado'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (!context.mounted) return;
      onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido marcado como pagado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
  );
}
